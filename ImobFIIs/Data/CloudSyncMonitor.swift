import CloudKit
import CoreData
import Foundation
import Observation

enum CloudSyncStatus: Equatable {
    case localOnly
    case noAccount
    case idle
    case syncing
    case synced(Date)
    case failed
}

struct CloudSyncEvent: Equatable, Sendable {
    let id: UUID
    let endDate: Date?
    let succeeded: Bool
}

struct CloudSyncState: Equatable {
    var isCloudEnabled: Bool
    var isAccountAvailable: Bool?
    var inFlightEvents: Set<UUID> = []
    var lastSuccess: Date?
    var lastEventFailed = false

    mutating func apply(_ event: CloudSyncEvent) {
        guard let endDate = event.endDate else {
            inFlightEvents.insert(event.id)
            return
        }
        inFlightEvents.remove(event.id)
        if event.succeeded {
            lastSuccess = max(lastSuccess ?? endDate, endDate)
            lastEventFailed = false
        } else {
            lastEventFailed = true
        }
    }

    var status: CloudSyncStatus {
        guard isCloudEnabled else { return .localOnly }
        if isAccountAvailable == false { return .noAccount }
        if !inFlightEvents.isEmpty { return .syncing }
        if lastEventFailed { return .failed }
        if let lastSuccess { return .synced(lastSuccess) }
        return .idle
    }
}

/// Acompanha os eventos de setup/import/export do `NSPersistentCloudKitContainer` usado pelo SwiftData.
@MainActor
@Observable
final class CloudSyncMonitor {
    private(set) var state: CloudSyncState

    var status: CloudSyncStatus { state.status }

    @ObservationIgnored private let containerIdentifier: String
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init(
        isCloudEnabled: Bool,
        containerIdentifier: String = Persistence.cloudKitContainerIdentifier,
        notificationCenter: NotificationCenter = .default
    ) {
        state = CloudSyncState(isCloudEnabled: isCloudEnabled)
        self.containerIdentifier = containerIdentifier
        self.notificationCenter = notificationCenter
        guard isCloudEnabled else { return }

        observers.append(notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event else { return }
            let snapshot = CloudSyncEvent(id: event.identifier, endDate: event.endDate, succeeded: event.succeeded)
            MainActor.assumeIsolated { self?.state.apply(snapshot) }
        })
        observers.append(notificationCenter.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccountStatus() }
        })
        refreshAccountStatus()
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }

    private func refreshAccountStatus() {
        let container = CKContainer(identifier: containerIdentifier)
        Task { [weak self] in
            let status = try? await container.accountStatus()
            self?.state.isAccountAvailable = status.map { $0 == .available }
        }
    }
}
