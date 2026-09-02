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

struct SentimentContext: Equatable, Sendable {
    var scoresByTicker: [String: Double]
    var confidenceByTicker: [String: SentimentConfidence]
    var summariesByTicker: [String: String]
    var labelsByTicker: [String: SentimentLabel]

    static let empty = SentimentContext(
        scoresByTicker: [:],
        confidenceByTicker: [:],
        summariesByTicker: [:],
        labelsByTicker: [:]
    )

    mutating func merge(_ report: SentimentSegmentReport) {
        for fund in report.funds {
            let ticker = fund.ticker.uppercased()
            scoresByTicker[ticker] = fund.score
            confidenceByTicker[ticker] = fund.confidence
            summariesByTicker[ticker] = fund.summary
            labelsByTicker[ticker] = fund.sentiment
        }
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
