import Foundation
import Testing
@testable import ImobFIIs

@Suite("Notícias no detalhe do fundo")
struct FundDetailSentimentTests {
    @Test @MainActor
    func loadsSentimentForTickerInSegmentReport() async {
        let viewModel = makeViewModel(ticker: "KNCR11", segment: .paper)

        await viewModel.loadSentiment()

        guard case .covered(let sentiment, let generatedAt) = viewModel.newsCoverage else {
            Issue.record("Expected covered state, got \(viewModel.newsCoverage)")
            return
        }
        #expect(sentiment.sentiment == .positive)
        #expect(sentiment.topHeadlines.count == 1)
        #expect(generatedAt == ISO8601DateFormatter().date(from: "2026-09-02T11:00:00Z"))
    }

    @Test @MainActor
    func reportsTickerNotCoveredWhenMissingFromSegmentReport() async {
        let viewModel = makeViewModel(ticker: "MXRF11", segment: .paper)

        await viewModel.loadSentiment()

        #expect(viewModel.newsCoverage == .tickerNotCovered)
    }

    @Test @MainActor
    func reportsSegmentNotCoveredWithoutFetching() async {
        let viewModel = makeViewModel(ticker: "KNCR11", segment: .hybrid, statusCode: 500)

        await viewModel.loadSentiment()

        #expect(viewModel.newsCoverage == .segmentNotCovered)
    }

    @Test @MainActor
    func reportsUnavailableWhenReportCannotBeLoaded() async {
        let viewModel = makeViewModel(ticker: "KNCR11", segment: .paper, statusCode: 500)

        await viewModel.loadSentiment()

        #expect(viewModel.newsCoverage == .unavailable)
    }

    @Test
    func flagsReportsOlderThanWeeklyRotation() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-09-29T12:00:00Z"))

        #expect(!SentimentFreshness.isStale(now.addingTimeInterval(-7 * 24 * 60 * 60), now: now))
        #expect(SentimentFreshness.isStale(now.addingTimeInterval(-9 * 24 * 60 * 60), now: now))
    }

    @Test
    func formatsHeadlineDates() {
        #expect(FundNewsSection.formattedDate(nil) == nil)
        #expect(FundNewsSection.formattedDate("") == nil)
        #expect(FundNewsSection.formattedDate("ontem") == "ontem")
        #expect(FundNewsSection.formattedDate("2026-08-28")?.contains("28") == true)
        #expect(FundNewsSection.formattedDate("2026-08-28") != "2026-08-28")
    }

    @MainActor
    private func makeViewModel(
        ticker: String,
        segment: FundSegment,
        statusCode: Int = 200
    ) -> FundDetailViewModel {
        let service = SentimentReportService(
            session: MockHTTPClient(data: Data(SentimentFixtures.paperReportJSON.utf8), statusCode: statusCode),
            baseURL: URL(string: "https://example.com/sentiment/")!,
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        return FundDetailViewModel(
            summary: FundSummary(
                ticker: ticker,
                name: ticker,
                longName: nil,
                segment: segment,
                currentPrice: nil,
                changePercent: nil,
                volume: nil,
                logoURL: nil
            ),
            catalog: MockFIICatalogService.sample,
            sentimentService: service
        )
    }
}
