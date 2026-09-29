import Foundation
import Testing
@testable import ImobFIIs

@Suite("Cache de relatórios de sentimento")
struct SentimentReportServiceTests {
    private let baseURL = URL(string: "https://example.com/sentiment/")!
    private let fetchedAt = Date(timeIntervalSince1970: 1_790_000_000)

    @Test
    func servesExpiredCacheWhenNetworkFails() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        _ = await makeService(statusCode: 200, defaults: defaults).report(for: "paper", now: fetchedAt)

        let offline = makeService(statusCode: 500, defaults: defaults)
        let report = await offline.report(for: "paper", now: fetchedAt.addingTimeInterval(3 * 24 * 60 * 60))

        #expect(report?.segmentKey == "paper")
        #expect(report?.sentiment(for: "KNCR11")?.sentiment == .positive)
    }

    @Test
    func servesFreshCacheWithoutNetwork() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        _ = await makeService(statusCode: 200, defaults: defaults).report(for: "paper", now: fetchedAt)

        let offline = makeService(statusCode: 500, defaults: defaults)
        let report = await offline.report(for: "paper", now: fetchedAt.addingTimeInterval(60 * 60))

        #expect(report?.segmentKey == "paper")
    }

    @Test
    func returnsNilWithoutNetworkOrCache() async {
        let service = makeService(statusCode: 500, defaults: UserDefaults(suiteName: UUID().uuidString)!)

        #expect(await service.report(for: "paper", now: fetchedAt) == nil)
    }

    @Test
    func mergesReportsFetchedForSeveralSegments() async {
        let service = SentimentReportService(
            session: RoutingHTTPClient(responses: [
                "paper.json": SentimentFixtures.paperReportJSON,
                "urban.json": SentimentFixtures.urbanTRXFReportJSON,
                "logistics.json": SentimentFixtures.logisticsTRXFReportJSON,
            ]),
            baseURL: baseURL,
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )

        let context = await service.reports(for: ["PAPER", "urban", "logistics", "paper"], now: fetchedAt)

        #expect(context.fund(for: "KNCR11", segmentKey: "paper")?.label == .positive)
        #expect(context.fund(for: "TRXF11", segmentKey: "urban")?.label == .negative)
        #expect(context.fund(for: "TRXF11", segmentKey: "logistics")?.label == .positive)
    }

    private func makeService(statusCode: Int, defaults: UserDefaults) -> SentimentReportService {
        SentimentReportService(
            session: MockHTTPClient(data: Data(SentimentFixtures.paperReportJSON.utf8), statusCode: statusCode),
            baseURL: baseURL,
            defaults: defaults
        )
    }
}

private struct RoutingHTTPClient: HTTPPerforming {
    let responses: [String: String]

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url, let body = responses[url.lastPathComponent],
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else {
            throw URLError(.fileDoesNotExist)
        }
        return (Data(body.utf8), response)
    }
}
