import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppLauncher {
    enum State {
        case ready(ModelContainer, CloudSyncMonitor)
        case failed(String)
    }

    private(set) var state: State
    private(set) var restoreFailed = false

    @ObservationIgnored private let load: @MainActor () throws -> AppPersistence
    @ObservationIgnored private let restore: @MainActor () throws -> Void

    init(
        load: @escaping @MainActor () throws -> AppPersistence,
        restore: @escaping @MainActor () throws -> Void
    ) {
        self.load = load
        self.restore = restore
        state = Self.state(from: load)
    }

    static func live() -> AppLauncher {
        if Persistence.isRunningTests {
            let container = Persistence.makeContainer(inMemory: true)
            return AppLauncher(
                load: { AppPersistence(container: container, isCloudSyncEnabled: false) },
                restore: {}
            )
        }
        let directory = URL.applicationSupportDirectory
        return AppLauncher(
            load: { try Persistence.loadAppPersistence(directory: directory) },
            restore: { try PersistenceRecovery.restoreFromBackup(in: directory) }
        )
    }

    func retry() {
        restoreFailed = false
        state = Self.state(from: load)
    }

    func restoreBackup() {
        do {
            try restore()
            retry()
        } catch {
            restoreFailed = true
        }
    }

    private static func state(from load: @MainActor () throws -> AppPersistence) -> State {
        do {
            let persistence = try load()
            return .ready(persistence.container, CloudSyncMonitor(isCloudEnabled: persistence.isCloudSyncEnabled))
        } catch {
            return .failed(String(describing: error))
        }
    }
}
