import Foundation

struct FundSummary: Identifiable, Hashable, Sendable {
    var id: String { ticker }

    var ticker: String
    var name: String
    var longName: String?
    var segment: FundSegment
    var currentPrice: Decimal?
    var changePercent: Double?
    var volume: Double?
    var logoURL: URL?

    var displayName: String {
        if let longName, !longName.isEmpty {
            return longName
        }
        return name
    }

    init(
        ticker: String,
        name: String,
        longName: String? = nil,
        segment: FundSegment,
        currentPrice: Decimal?,
        changePercent: Double? = nil,
        volume: Double? = nil,
        logoURL: URL? = nil
    ) {
        self.ticker = ticker
        self.name = name
        self.longName = longName
        self.segment = segment
        self.currentPrice = currentPrice
        self.changePercent = changePercent
        self.volume = volume
        self.logoURL = logoURL
    }

    init(fund: Fund) {
        self.init(
            ticker: fund.ticker,
            name: fund.name,
            segment: fund.segment,
            currentPrice: fund.currentPrice
        )
    }
}
