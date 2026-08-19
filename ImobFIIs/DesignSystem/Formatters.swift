import Foundation

extension FormatStyle where Self == Decimal.FormatStyle.Currency {
    static var brl: Decimal.FormatStyle.Currency {
        .currency(code: "BRL").locale(Locale(identifier: "pt_BR"))
    }
}

extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Percent {
    static var fiiYield: FloatingPointFormatStyle<Double>.Percent {
        .percent
            .precision(.fractionLength(1...2))
            .locale(Locale(identifier: "pt_BR"))
    }

    static var marketChange: FloatingPointFormatStyle<Double>.Percent {
        .percent
            .precision(.fractionLength(2))
            .sign(strategy: .always())
            .locale(Locale(identifier: "pt_BR"))
    }
}

extension Collection where Element == Holding {
    var investedAmount: Decimal {
        reduce(0) { $0 + $1.investedAmount }
    }

    var currentValue: Decimal {
        reduce(0) { $0 + $1.currentValue }
    }

    var estimatedMonthlyIncome: Decimal {
        reduce(0) { $0 + $1.estimatedMonthlyIncome }
    }

    var profitAndLoss: Decimal {
        currentValue - investedAmount
    }
}
