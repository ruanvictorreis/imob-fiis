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

        let fetched = await Self.fetchReport(from: reportURL(for: key), session: session)
        return resolve(fetched, segmentKey: key, now: now)
    }

    func reports(for segmentKeys: [String], now: Date = .now) async -> SentimentContext {
        let keys = Set(segmentKeys.map { $0.lowercased() }).sorted()
        var reports: [String: SentimentSegmentReport] = [:]
        var keysToFetch: [(key: String, url: URL?)] = []
        for key in keys {
            if let cached = cachedReport(for: key, now: now) {
                reports[key] = cached
            } else {
                keysToFetch.append((key, reportURL(for: key)))
            }
        }

        let session = session
        let fetched = await withTaskGroup(of: (String, SentimentSegmentReport?).self) { group in
            for entry in keysToFetch {
                group.addTask { (entry.key, await Self.fetchReport(from: entry.url, session: session)) }
            }
            var results: [String: SentimentSegmentReport?] = [:]
            for await (key, report) in group {
                results[key] = report
            }
            return results
        }
        for (key, report) in fetched {
            reports[key] = resolve(report, segmentKey: key, now: now)
        }

        var context = SentimentContext.empty
        for key in keys {
            if let report = reports[key] {
                context.merge(report)
            }
        }
        return context
    }

    private func resolve(
        _ fetched: SentimentSegmentReport?,
        segmentKey: String,
        now: Date
    ) -> SentimentSegmentReport? {
        guard let fetched else {
            return cachedReport(for: segmentKey, now: now, allowExpired: true)
        }
        store(report: fetched, segmentKey: segmentKey, fetchedAt: now)
        return fetched
    }

    private static func fetchReport(
        from url: URL?,
        session: any HTTPPerforming
    ) async -> SentimentSegmentReport? {
        guard let url else { return nil }
        do {
            let (data, response) = try await session.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SentimentSegmentReport.self, from: data)
        } catch {
            return nil
        }
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

    /// Sem rede, um relatório antigo é melhor que nenhum: `allowExpired` ignora o TTL.
    private func cachedReport(
        for segmentKey: String,
        now: Date,
        allowExpired: Bool = false
    ) -> SentimentSegmentReport? {
        guard let fetchedAt = defaults.object(forKey: cacheDateKey(for: segmentKey)) as? Date else {
            return nil
        }
        guard allowExpired || now.timeIntervalSince(fetchedAt) < cacheTTL else { return nil }
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
