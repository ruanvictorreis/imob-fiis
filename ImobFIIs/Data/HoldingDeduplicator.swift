import Foundation
import SwiftData

/// O CloudKit não garante unicidade: o mesmo ticker pode chegar de dois aparelhos
/// (ex.: posição adicionada offline em ambos). Mantém só a posição alterada por último.
enum HoldingDeduplicator {
    @MainActor
    @discardableResult
    static func removeDuplicates(in context: ModelContext) -> Int {
        guard let holdings = try? context.fetch(FetchDescriptor<Holding>()) else { return 0 }

        var removed = 0
        let groups = Dictionary(grouping: holdings.filter { !$0.ticker.isEmpty }, by: \.ticker)
        for group in groups.values where group.count > 1 {
            for duplicate in group.sorted(by: isMoreRecent).dropFirst() {
                context.delete(duplicate)
                removed += 1
            }
        }
        return removed
    }

    static func isMoreRecent(_ lhs: Holding, _ rhs: Holding) -> Bool {
        let left = lhs.updatedAt ?? .distantPast
        let right = rhs.updatedAt ?? .distantPast
        if left != right {
            return left > right
        }
        return lhs.purchasedAt > rhs.purchasedAt
    }
}
