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

        #expect(context.fund(for: "KNCR11", segmentKey: "paper")?.score == 0.55)
        #expect(context.fund(for: "CPTS11", segmentKey: "paper")?.label == .neutral)
        #expect(context.fund(for: "KNCR11", segmentKey: "paper")?.summary.isEmpty == false)
    }

    @Test
    func usesSegmentSpecificSentimentWhenTickerAppearsInMultipleReports() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let urban = try decoder.decode(
            SentimentSegmentReport.self,
            from: SentimentFixtures.urbanTRXFReportJSON.data(using: .utf8)!
        )
        let logistics = try decoder.decode(
            SentimentSegmentReport.self,
            from: SentimentFixtures.logisticsTRXFReportJSON.data(using: .utf8)!
        )

        var context = SentimentContext.empty
        context.merge(logistics)
        context.merge(urban)

        #expect(context.fund(for: "TRXF11", segmentKey: "urban")?.label == .negative)
        #expect(context.fund(for: "TRXF11", segmentKey: "logistics")?.label == .positive)
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

    static let urbanTRXFReportJSON = """
    {
      "version": 1,
      "segment": "Renda Urbana",
      "segmentKey": "urban",
      "generatedAt": "2026-09-02T11:00:00Z",
      "lookbackDays": 14,
      "sources": ["clube.fii"],
      "funds": [
        {
          "ticker": "TRXF11",
          "sentiment": "negative",
          "score": -0.25,
          "confidence": "high",
          "summary": "Queda da cota e cancelamentos.",
          "articleCount": 2,
          "topHeadlines": []
        }
      ]
    }
    """

    static let logisticsTRXFReportJSON = """
    {
      "version": 1,
      "segment": "Logística",
      "segmentKey": "logistics",
      "generatedAt": "2026-09-02T11:00:00Z",
      "lookbackDays": 14,
      "sources": ["clube.fii"],
      "funds": [
        {
          "ticker": "TRXF11",
          "sentiment": "positive",
          "score": 0.5,
          "confidence": "medium",
          "summary": "Expansão logística.",
          "articleCount": 2,
          "topHeadlines": []
        }
      ]
    }
    """
}
