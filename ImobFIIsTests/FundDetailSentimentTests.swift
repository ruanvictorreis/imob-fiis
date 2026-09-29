import Foundation
import Testing
@testable import ImobFIIs

@Suite("Notícias no detalhe do fundo")
struct FundDetailSentimentTests {
    @Test @MainActor
    func loadsSentimentForTickerInSegmentReport() async {
        let viewModel = makeViewModel(ticker: "KNCR11", segment: .paper)

        await viewModel.loadSentiment()

        #expect(viewModel.sentiment?.sentiment == .positive)
        #expect(viewModel.sentiment?.topHeadlines.count == 1)
        #expect(viewModel.sentimentGeneratedAt == ISO8601DateFormatter().date(from: "2026-09-02T11:00:00Z"))
    }

    @Test @MainActor
    func leavesSentimentEmptyWhenTickerIsNotCovered() async {
        let viewModel = makeViewModel(ticker: "MXRF11", segment: .paper)

        await viewModel.loadSentiment()

        #expect(viewModel.sentiment == nil)
        #expect(viewModel.sentimentGeneratedAt == nil)
    }

    @Test @MainActor
    func skipsSegmentsWithoutSentimentReports() async {
        let viewModel = makeViewModel(ticker: "KNCR11", segment: .hybrid)

        await viewModel.loadSentiment()

        #expect(viewModel.sentiment == nil)
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
    private func makeViewModel(ticker: String, segment: FundSegment) -> FundDetailViewModel {
        let service = SentimentReportService(
            session: MockHTTPClient(data: Data(SentimentFixtures.paperReportJSON.utf8), statusCode: 200),
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
