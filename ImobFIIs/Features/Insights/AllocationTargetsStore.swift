import Foundation
import Observation

@Observable
final class AllocationTargetsStore {
    static let storageKey = "insights.allocationTargets"

    private let defaults: UserDefaults
    private(set) var targetWeights: [FundSegment: Double]

    var strategy: CustomAllocationStrategy {
        CustomAllocationStrategy(targetWeights: targetWeights)
    }

    var orderedSegments: [FundSegment] {
        BalancedRetailStrategy().orderedSegments
    }

    var isUsingDefaults: Bool {
        targetWeights == Self.defaultWeights
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.targetWeights = Self.load(from: defaults) ?? Self.defaultWeights
    }

    func weight(for segment: FundSegment) -> Double {
        targetWeights[segment] ?? 0
    }

    func setWeight(_ weight: Double, for segment: FundSegment) {
        let clamped = min(max(weight, 0), 1)
        targetWeights[segment] = clamped
    }

    func replaceAll(_ weights: [FundSegment: Double]) {
        targetWeights = Dictionary(
            uniqueKeysWithValues: orderedSegments.map { segment in
                (segment, min(max(weights[segment] ?? 0, 0), 1))
            }
        )
    }

    @discardableResult
    func save() -> Bool {
        guard Self.isValid(targetWeights) else { return false }
        let payload = Dictionary(
            uniqueKeysWithValues: targetWeights.map { ($0.key.rawValue, $0.value) }
        )
        defaults.set(payload, forKey: Self.storageKey)
        return true
    }

    func resetToDefaults() {
        targetWeights = Self.defaultWeights
        defaults.removeObject(forKey: Self.storageKey)
    }

    func reload() {
        targetWeights = Self.load(from: defaults) ?? Self.defaultWeights
    }

    static var defaultWeights: [FundSegment: Double] {
        BalancedRetailStrategy().targetWeights
    }

    static func isValid(_ weights: [FundSegment: Double]) -> Bool {
        let segments = BalancedRetailStrategy().orderedSegments
        let total = segments.reduce(0.0) { $0 + (weights[$1] ?? 0) }
        return abs(total - 1) < 0.000_5
    }

    private static func load(from defaults: UserDefaults) -> [FundSegment: Double]? {
        guard let payload = defaults.dictionary(forKey: storageKey) as? [String: Double] else {
            return nil
        }

        var weights: [FundSegment: Double] = [:]
        for segment in BalancedRetailStrategy().orderedSegments {
            weights[segment] = payload[segment.rawValue] ?? 0
        }
        return isValid(weights) ? weights : nil
    }
}
