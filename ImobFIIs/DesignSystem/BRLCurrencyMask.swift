import Foundation

enum BRLCurrencyMask {
    static let maxCents = 99_999_999

    static func cents(fromAmount amount: Decimal?) -> Int {
        guard let amount, amount > 0 else { return 0 }
        var value = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        let cents = NSDecimalNumber(decimal: rounded).intValue
        return min(max(cents, 0), maxCents)
    }

    static func amount(fromCents cents: Int) -> Decimal? {
        guard cents > 0 else { return nil }
        return Decimal(min(cents, maxCents)) / 100
    }

    static func cents(fromTypedText text: String) -> Int {
        let digits = text.filter(\.isNumber)
        guard let value = Int(digits) else { return 0 }
        return min(value, maxCents)
    }

    static func formatted(cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.brlInput)
    }
}
