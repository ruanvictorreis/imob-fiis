import Foundation
import Observation

/// Metas de alocação salvas em `UserDefaults` e espelhadas no iCloud Key-Value Storage,
/// que é a fonte de verdade quando disponível (última gravação vence entre aparelhos).
@MainActor
@Observable
final class AllocationTargetsStore {
    static let storageKey = "insights.allocationTargets"
    static let promptKey = "insights.didPromptForTargets"

    private let defaults: UserDefaults
    private let cloud: CloudKeyValueStoring?
    private let notificationCenter: NotificationCenter
    @ObservationIgnored nonisolated(unsafe) private var cloudObserver: NSObjectProtocol?
    private(set) var targetWeights: [FundSegment: Double]
    private(set) var hasSavedTargets: Bool
    private(set) var didPromptForTargets: Bool

    var strategy: CustomAllocationStrategy {
        CustomAllocationStrategy(targetWeights: targetWeights)
    }

    var orderedSegments: [FundSegment] {
        BalancedRetailStrategy().orderedSegments
    }

    var isUsingDefaults: Bool {
        targetWeights == Self.defaultWeights
    }

    var shouldAutoPresentTargetsEditor: Bool {
        !hasSavedTargets && !didPromptForTargets
    }

    init(
        defaults: UserDefaults = .standard,
        cloud: CloudKeyValueStoring? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.cloud = cloud
        self.notificationCenter = notificationCenter
        self.targetWeights = Self.defaultWeights
        self.hasSavedTargets = false
        self.didPromptForTargets = defaults.bool(forKey: Self.promptKey)

        if let cloud {
            cloud.synchronize()
            mergeCloudIntoDefaults()
            cloudObserver = notificationCenter.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: cloud,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleCloudChange()
                }
            }
        }
        reload()
    }

    deinit {
        if let cloudObserver {
            notificationCenter.removeObserver(cloudObserver)
        }
    }

    static func live() -> AllocationTargetsStore {
        AllocationTargetsStore(cloud: NSUbiquitousKeyValueStore.default)
    }

    func markTargetsPrompted() {
        didPromptForTargets = true
        defaults.set(true, forKey: Self.promptKey)
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
        cloud?.set(payload, forKey: Self.storageKey)
        cloud?.synchronize()
        hasSavedTargets = true
        markTargetsPrompted()
        return true
    }

    func resetToDefaults() {
        targetWeights = Self.defaultWeights
        defaults.removeObject(forKey: Self.storageKey)
        cloud?.removeObject(forKey: Self.storageKey)
        cloud?.synchronize()
        hasSavedTargets = false
    }

    func reload() {
        targetWeights = Self.load(from: defaults.dictionary(forKey: Self.storageKey)) ?? Self.defaultWeights
        hasSavedTargets = defaults.object(forKey: Self.storageKey) != nil
        didPromptForTargets = defaults.bool(forKey: Self.promptKey)
    }

    func handleCloudChange() {
        guard let cloud else { return }
        if let payload = cloud.dictionary(forKey: Self.storageKey), Self.load(from: payload) != nil {
            defaults.set(payload, forKey: Self.storageKey)
        } else {
            defaults.removeObject(forKey: Self.storageKey)
        }
        reload()
    }

    /// Na primeira abertura com iCloud, metas salvas só neste aparelho sobem para a nuvem.
    private func mergeCloudIntoDefaults() {
        guard let cloud else { return }
        if let payload = cloud.dictionary(forKey: Self.storageKey), Self.load(from: payload) != nil {
            defaults.set(payload, forKey: Self.storageKey)
        } else if let local = defaults.dictionary(forKey: Self.storageKey), Self.load(from: local) != nil {
            cloud.set(local, forKey: Self.storageKey)
            cloud.synchronize()
        }
    }

    static var defaultWeights: [FundSegment: Double] {
        BalancedRetailStrategy().targetWeights
    }

    static func isValid(_ weights: [FundSegment: Double]) -> Bool {
        let segments = BalancedRetailStrategy().orderedSegments
        let total = segments.reduce(0.0) { $0 + (weights[$1] ?? 0) }
        return abs(total - 1) < 0.000_5
    }

    private static func load(from payload: [String: Any]?) -> [FundSegment: Double]? {
        guard let payload = payload as? [String: Double] else { return nil }

        var weights: [FundSegment: Double] = [:]
        for segment in BalancedRetailStrategy().orderedSegments {
            weights[segment] = payload[segment.rawValue] ?? 0
        }
        return isValid(weights) ? weights : nil
    }
}
