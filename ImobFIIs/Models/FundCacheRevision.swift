import Observation

/// Invalida as views que leram `Holding.fund` antes de o fundo existir no cache local
/// (ex.: posição recém-sincronizada do iCloud em outro aparelho).
@Observable
final class FundCacheRevision {
    nonisolated(unsafe) static let shared = FundCacheRevision()

    private var value = 0

    func observe() {
        _ = value
    }

    func fundInserted() {
        value &+= 1
    }
}
