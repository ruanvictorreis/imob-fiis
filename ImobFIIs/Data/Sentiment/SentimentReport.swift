import Foundation

enum SentimentLabel: String, Codable, Equatable, Sendable {
    case positive
    case neutral
    case negative
}

enum SentimentConfidence: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

struct SentimentHeadline: Codable, Equatable, Sendable {
    var title: String
    var url: URL
    var publishedAt: String?
}

struct FundSentiment: Codable, Equatable, Sendable, Identifiable {
    var id: String { ticker.uppercased() }

    var ticker: String
    var sentiment: SentimentLabel
    var score: Double
    var confidence: SentimentConfidence
    var summary: String
    var articleCount: Int
    var topHeadlines: [SentimentHeadline]
}

struct SentimentSegmentReport: Codable, Equatable, Sendable {
    var version: Int
    var segment: String
    var segmentKey: String
    var generatedAt: Date
    var lookbackDays: Int
    var sources: [String]
    var funds: [FundSentiment]

    func sentiment(for ticker: String) -> FundSentiment? {
        funds.first { $0.ticker.uppercased() == ticker.uppercased() }
    }
}

struct SentimentManifest: Codable, Equatable, Sendable {
    struct SegmentEntry: Codable, Equatable, Sendable {
        var updatedAt: String
        var fundCount: Int
        var url: String
    }

    var version: Int
    var updatedAt: String
    var segments: [String: SegmentEntry]
}

struct SentimentFundSnapshot: Equatable, Sendable {
    var score: Double
    var confidence: SentimentConfidence
    var label: SentimentLabel
    var summary: String
}

struct SentimentContext: Equatable, Sendable {
    /// segmentKey normalizado -> ticker normalizado -> snapshot
    var fundsBySegment: [String: [String: SentimentFundSnapshot]]

    static let empty = SentimentContext(fundsBySegment: [:])

    mutating func merge(_ report: SentimentSegmentReport) {
        let segmentKey = report.segmentKey.lowercased()
        var segmentFunds = fundsBySegment[segmentKey] ?? [:]
        for fund in report.funds {
            let ticker = fund.ticker.uppercased()
            segmentFunds[ticker] = SentimentFundSnapshot(
                score: fund.score,
                confidence: fund.confidence,
                label: fund.sentiment,
                summary: fund.summary
            )
        }
        fundsBySegment[segmentKey] = segmentFunds
    }

    func fund(for ticker: String, segmentKey: String) -> SentimentFundSnapshot? {
        fundsBySegment[segmentKey.lowercased()]?[ticker.uppercased()]
    }
}

enum SentimentConfiguration {
    static var baseURL: URL {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "SENTIMENT_BASE_URL") as? String,
           let url = URL(string: urlString) {
            return url
        }
        return URL(string: "https://ruanvictorreis.github.io/imob-fiis/sentiment/")!
    }
}
