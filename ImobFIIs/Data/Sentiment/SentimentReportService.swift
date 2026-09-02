import Foundation

struct SentimentReportService {
    var session: any HTTPPerforming
    var baseURL: URL
    var defaults: UserDefaults
    var cacheTTL: TimeInterval

    init(
        session: any HTTPPerforming = URLSession.shared,
        baseURL: URL = SentimentConfiguration.baseURL,
        defaults: UserDefaults = .standard,
        cacheTTL: TimeInterval = 60 * 60 * 24
    ) {
        self.session = session
        self.baseURL = baseURL
        self.defaults = defaults
        self.cacheTTL = cacheTTL
    }

    func report(for segmentKey: String, now: Date = .now, force: Bool = false) async -> SentimentSegmentReport? {
        let key = segmentKey.lowercased()
        if !force, let cached = cachedReport(for: key, now: now) {
            return cached
        }

        guard let url = reportURL(for: key) else { return cachedReport(for: key, now: now) }

        do {
            let request = URLRequest(url: url)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                return cachedReport(for: key, now: now)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let report = try decoder.decode(SentimentSegmentReport.self, from: data)
            store(report: report, segmentKey: key, fetchedAt: now)
            return report
        } catch {
            return cachedReport(for: key, now: now)
        }
    }

    func reports(for segmentKeys: [String], now: Date = .now) async -> SentimentContext {
        var context = SentimentContext.empty
        for key in Set(segmentKeys.map { $0.lowercased() }).sorted() {
            guard let report = await report(for: key, now: now) else { continue }
            context.merge(report)
        }
        return context
    }

    private func reportURL(for segmentKey: String) -> URL? {
        baseURL.appendingPathComponent("\(segmentKey).json")
    }

    private func cacheKey(for segmentKey: String) -> String {
        "sentiment.report.\(segmentKey)"
    }

    private func cacheDateKey(for segmentKey: String) -> String {
        "sentiment.reportAt.\(segmentKey)"
    }

    private func cachedReport(for segmentKey: String, now: Date) -> SentimentSegmentReport? {
        guard let fetchedAt = defaults.object(forKey: cacheDateKey(for: segmentKey)) as? Date else {
            return nil
        }
        guard now.timeIntervalSince(fetchedAt) < cacheTTL else { return nil }
        guard let data = defaults.data(forKey: cacheKey(for: segmentKey)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SentimentSegmentReport.self, from: data)
    }

    private func store(report: SentimentSegmentReport, segmentKey: String, fetchedAt: Date) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report) else { return }
        defaults.set(data, forKey: cacheKey(for: segmentKey))
        defaults.set(fetchedAt, forKey: cacheDateKey(for: segmentKey))
    }
}
