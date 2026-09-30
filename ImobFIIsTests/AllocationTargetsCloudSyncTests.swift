import Foundation
import Testing
@testable import ImobFIIs

@Suite("Metas de alocação no iCloud")
@MainActor
struct AllocationTargetsCloudSyncTests {
    private let custom: [FundSegment: Double] = [
        .paper: 0.20,
        .urban: 0.25,
        .logistics: 0.20,
        .malls: 0.15,
        .offices: 0.10,
        .fiagro: 0.10,
    ]

    @Test
    func savingWritesTargetsToCloud() throws {
        let cloud = FakeCloudKeyValueStore()
        let store = AllocationTargetsStore(defaults: makeDefaults(), cloud: cloud)

        store.replaceAll(custom)
        #expect(store.save())

        let payload = try #require(cloud.dictionary(forKey: AllocationTargetsStore.storageKey) as? [String: Double])
        #expect(payload[FundSegment.urban.rawValue] == 0.25)
    }

    @Test
    func prefersTargetsSavedOnAnotherDevice() {
        let cloud = FakeCloudKeyValueStore()
        cloud.set(payload(custom), forKey: AllocationTargetsStore.storageKey)

        let store = AllocationTargetsStore(defaults: makeDefaults(), cloud: cloud)

        #expect(store.hasSavedTargets)
        #expect(store.weight(for: .urban) == 0.25)
        #expect(!store.shouldAutoPresentTargetsEditor)
    }

    @Test
    func uploadsLocalTargetsWhenCloudIsEmpty() {
        let defaults = makeDefaults()
        defaults.set(payload(custom), forKey: AllocationTargetsStore.storageKey)
        let cloud = FakeCloudKeyValueStore()

        _ = AllocationTargetsStore(defaults: defaults, cloud: cloud)

        #expect((cloud.dictionary(forKey: AllocationTargetsStore.storageKey) as? [String: Double])?.count == 6)
    }

    @Test
    func reloadsWhenTargetsChangeOnAnotherDevice() {
        let cloud = FakeCloudKeyValueStore()
        let store = AllocationTargetsStore(defaults: makeDefaults(), cloud: cloud)
        #expect(store.isUsingDefaults)

        cloud.set(payload(custom), forKey: AllocationTargetsStore.storageKey)
        store.handleCloudChange()
        #expect(store.weight(for: .urban) == 0.25)

        cloud.removeObject(forKey: AllocationTargetsStore.storageKey)
        store.handleCloudChange()
        #expect(store.isUsingDefaults)
        #expect(!store.hasSavedTargets)
    }

    @Test
    func resetRemovesTargetsFromCloud() {
        let cloud = FakeCloudKeyValueStore()
        let store = AllocationTargetsStore(defaults: makeDefaults(), cloud: cloud)
        store.replaceAll(custom)
        store.save()

        store.resetToDefaults()

        #expect(cloud.dictionary(forKey: AllocationTargetsStore.storageKey) == nil)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    private func payload(_ weights: [FundSegment: Double]) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: weights.map { ($0.key.rawValue, $0.value) })
    }
}

private final class FakeCloudKeyValueStore: CloudKeyValueStoring {
    private var values: [String: Any] = [:]

    func dictionary(forKey key: String) -> [String: Any]? {
        values[key] as? [String: Any]
    }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }

    func removeObject(forKey key: String) {
        values[key] = nil
    }

    func synchronize() -> Bool {
        true
    }
}
