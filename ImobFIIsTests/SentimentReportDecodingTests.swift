import Foundation
import Testing
@testable import ImobFIIs

@Suite("Decodificação de relatório de sentimento")
struct SentimentReportDecodingTests {
    @Test
    func decodesSegmentReportFixture() throws {
        let data = SentimentFixtures.paperReportJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let report = try decoder.decode(SentimentSegmentReport.self, from: data)

        #expect(report.segmentKey == "paper")
        #expect(report.funds.count == 2)
        #expect(report.funds[0].ticker == "KNCR11")
        #expect(report.funds[0].sentiment == .positive)
        #expect(report.funds[0].score == 0.55)
        #expect(report.sentiment(for: "KNCR11")?.confidence == .medium)
    }

    @Test
    func mergesReportsIntoContext() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = SentimentFixtures.paperReportJSON.data(using: .utf8)!
        let report = try decoder.decode(SentimentSegmentReport.self, from: data)

        var context = SentimentContext.empty
        context.merge(report)

        #expect(context.scoresByTicker["KNCR11"] == 0.55)
        #expect(context.labelsByTicker["CPTS11"] == .neutral)
        #expect(context.summariesByTicker["KNCR11"]?.isEmpty == false)
    }
}

enum SentimentFixtures {
    static let paperReportJSON = """
    {
      "version": 1,
      "segment": "Papel",
      "segmentKey": "paper",
      "generatedAt": "2026-09-02T11:00:00Z",
      "lookbackDays": 14,
      "sources": ["clube.fii"],
      "funds": [
        {
          "ticker": "KNCR11",
          "sentiment": "positive",
          "score": 0.55,
          "confidence": "medium",
          "summary": "Cobertura positiva.",
          "articleCount": 3,
          "topHeadlines": [
            {
              "title": "KNCR11 em foco",
              "url": "https://www.fundsexplorer.com.br/funds/kncr11",
              "publishedAt": "2026-08-28"
            }
          ]
        },
        {
          "ticker": "CPTS11",
          "sentiment": "neutral",
          "score": 0.05,
          "confidence": "low",
          "summary": "Sem destaque.",
          "articleCount": 0,
          "topHeadlines": []
        }
      ]
    }
    """
}
