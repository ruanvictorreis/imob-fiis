import SwiftUI

struct CloudSyncStatusLabel: View {
    let status: CloudSyncStatus

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(isWarning ? Color.orange : Color.appSecondaryText)
            .symbolEffect(.pulse, isActive: status == .syncing)
    }

    private var title: String {
        switch status {
        case .localOnly:
            L10n.Sync.localOnly
        case .noAccount:
            L10n.Sync.noAccount
        case .idle:
            L10n.Sync.idle
        case .syncing:
            L10n.Sync.syncing
        case .synced(let date):
            L10n.Sync.synced(date.formatted(date: .omitted, time: .shortened))
        case .failed:
            L10n.Sync.failed
        }
    }

    private var symbol: String {
        switch status {
        case .localOnly, .noAccount:
            "icloud.slash"
        case .idle:
            "icloud"
        case .syncing:
            "arrow.triangle.2.circlepath.icloud"
        case .synced:
            "checkmark.icloud"
        case .failed:
            "exclamationmark.icloud"
        }
    }

    private var isWarning: Bool {
        status == .noAccount || status == .failed
    }
}
