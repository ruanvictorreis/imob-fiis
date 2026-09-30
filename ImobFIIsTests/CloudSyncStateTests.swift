import Foundation
import Testing
@testable import ImobFIIs

@Suite("Status da sincronização com o iCloud")
struct CloudSyncStateTests {
    @Test
    func reportsLocalOnlyWhenCloudKitIsDisabled() {
        var state = CloudSyncState(isCloudEnabled: false)
        state.apply(CloudSyncEvent(id: UUID(), endDate: nil, succeeded: false))

        #expect(state.status == .localOnly)
    }

    @Test
    func reportsMissingAccount() {
        var state = CloudSyncState(isCloudEnabled: true)
        state.isAccountAvailable = false

        #expect(state.status == .noAccount)
    }

    @Test
    func tracksEventsUntilAllFinish() {
        let importID = UUID()
        let exportID = UUID()
        let finished = Date(timeIntervalSince1970: 1_800_000_000)
        var state = CloudSyncState(isCloudEnabled: true, isAccountAvailable: true)
        #expect(state.status == .idle)

        state.apply(CloudSyncEvent(id: importID, endDate: nil, succeeded: false))
        state.apply(CloudSyncEvent(id: exportID, endDate: nil, succeeded: false))
        state.apply(CloudSyncEvent(id: importID, endDate: finished, succeeded: true))
        #expect(state.status == .syncing)

        state.apply(CloudSyncEvent(id: exportID, endDate: finished.addingTimeInterval(5), succeeded: true))
        #expect(state.status == .synced(finished.addingTimeInterval(5)))
    }

    @Test
    func failureClearsAfterNextSuccessfulEvent() {
        let finished = Date(timeIntervalSince1970: 1_800_000_000)
        var state = CloudSyncState(isCloudEnabled: true)

        state.apply(CloudSyncEvent(id: UUID(), endDate: finished, succeeded: false))
        #expect(state.status == .failed)

        state.apply(CloudSyncEvent(id: UUID(), endDate: finished.addingTimeInterval(60), succeeded: true))
        #expect(state.status == .synced(finished.addingTimeInterval(60)))
    }
}
