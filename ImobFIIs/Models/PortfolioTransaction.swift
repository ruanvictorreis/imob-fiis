import Foundation
import SwiftData

enum TransactionKind: String, Codable, CaseIterable {
    /// Posição que existia antes do histórico; soma como uma compra.
    case openingBalance
    case buy
    case sell
    /// Define a posição (cotas e preço médio) a partir da data do lançamento.
    case adjustment
}

/// Operação na carteira. Fica no store sincronizado via CloudKit, ligada à posição pelo ticker.
@Model
final class PortfolioTransaction {
    var ticker: String = ""
    var kindRaw: String = TransactionKind.buy.rawValue
    var shares: Int = 0
    var price: Decimal = 0
    var date: Date = Date.now
    var createdAt: Date = Date.now
    var notes: String = ""

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .buy }
        set { kindRaw = newValue.rawValue }
    }

    init(
        ticker: String,
        kind: TransactionKind,
        shares: Int,
        price: Decimal,
        date: Date = .now,
        createdAt: Date = .now,
        notes: String = ""
    ) {
        self.ticker = ticker
        self.kindRaw = kind.rawValue
        self.shares = shares
        self.price = price
        self.date = date
        self.createdAt = createdAt
        self.notes = notes
    }
}
