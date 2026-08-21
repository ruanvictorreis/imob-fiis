import Foundation
import Testing
@testable import ImobFIIs

@Suite("Metas de alocação")
struct AllocationTargetsStoreTests {
    @Test
    func startsWithBalancedRetailDefaults() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = AllocationTargetsStore(defaults: defaults)

        #expect(store.targetWeights == AllocationTargetsStore.defaultWeights)
        #expect(store.isUsingDefaults)
        #expect(store.strategy.targetWeights[.paper] == 0.30)
        #expect(store.orderedSegments.count == FundSegment.allCases.count)
        #expect(store.weight(for: .hybrid) == 0)
        #expect(store.weight(for: .fundsOfFunds) == 0)
        #expect(store.weight(for: .residential) == 0)
        #expect(store.weight(for: .other) == 0)
    }

    @Test
    func savesAndReloadsCustomWeights() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store = AllocationTargetsStore(defaults: defaults)

        store.replaceAll([
            .paper: 0.20,
            .urban: 0.25,
            .logistics: 0.20,
            .malls: 0.15,
            .offices: 0.10,
            .fiagro: 0.10,
        ])
        #expect(store.save())

        let reloaded = AllocationTargetsStore(defaults: defaults)
        #expect(reloaded.weight(for: .paper) == 0.20)
        #expect(reloaded.weight(for: .urban) == 0.25)
        #expect(reloaded.weight(for: .fiagro) == 0.10)
        #expect(!reloaded.isUsingDefaults)
    }

    @Test
    func rejectsInvalidTotalWhenSaving() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = AllocationTargetsStore(defaults: defaults)

        store.setWeight(0.50, for: .paper)
        #expect(!store.save())
        #expect(defaults.object(forKey: AllocationTargetsStore.storageKey) == nil)
    }

    @Test
    func resetClearsPersistedWeights() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = AllocationTargetsStore(defaults: defaults)

        store.replaceAll([
            .paper: 0.20,
            .urban: 0.25,
            .logistics: 0.20,
            .malls: 0.15,
            .offices: 0.10,
            .fiagro: 0.10,
        ])
        #expect(store.save())

        store.resetToDefaults()
        #expect(store.isUsingDefaults)
        #expect(defaults.object(forKey: AllocationTargetsStore.storageKey) == nil)
    }

    @Test
    func customStrategyFeedsInsightEngine() {
        let strategy = CustomAllocationStrategy(
            targetWeights: [
                .paper: 0.20,
                .urban: 0.25,
                .logistics: 0.20,
                .malls: 0.15,
                .offices: 0.10,
                .fiagro: 0.10,
            ]
        )

        #expect(strategy.targetWeights[.paper] == 0.20)
        #expect(AllocationTargetsStore.isValid(strategy.targetWeights))
    }
}
