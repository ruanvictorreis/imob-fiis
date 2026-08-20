import Foundation

protocol DividendFallbackServing: Sendable {
    func latestDividends(for symbols: [String]) async -> [FIIDividend]
}

struct YahooDividendFallback: DividendFallbackServing {
    var session: any HTTPPerforming
    var baseURL: URL

    init(
        session: any HTTPPerforming = URLSession.shared,
        baseURL: URL = URL(string: "https://query1.finance.yahoo.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func latestDividends(for symbols: [String]) async -> [FIIDividend] {
        var collected: [FIIDividend] = []
        for symbol in symbols where !symbol.isEmpty {
            if let dividend = await latestDividend(for: symbol) {
                collected.append(dividend)
            }
        }
        return collected
    }

    private func latestDividend(for symbol: String) async -> FIIDividend? {
        guard let request = makeRequest(for: symbol) else { return nil }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            return FIIDividend(ticker: symbol.uppercased(), chart: decoded)
        } catch {
            return nil
        }
    }

    private func makeRequest(for symbol: String) -> URLRequest? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = "/v8/finance/chart/\(Self.yahooSymbol(for: symbol))"
        components.queryItems = [
            URLQueryItem(name: "range", value: "6mo"),
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "events", value: "div"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    static func yahooSymbol(for ticker: String) -> String {
        let trimmed = ticker
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ".SA", with: "")
        return "\(trimmed).SA"
    }
}

private struct YahooChartResponse: Decodable {
    var chart: YahooChart
}

private struct YahooChart: Decodable {
    var result: [YahooChartResult]?
}

private struct YahooChartResult: Decodable {
    var events: YahooChartEvents?
}

private struct YahooChartEvents: Decodable {
    var dividends: [String: YahooDividendEvent]?
}

private struct YahooDividendEvent: Decodable {
    var amount: Double
    var date: Int
}

extension FIIDividend {
    fileprivate init?(ticker: String, chart: YahooChartResponse) {
        guard let latest = chart.chart.result?.first?.events?.dividends?.values.max(by: { $0.date < $1.date }),
              let rate = Decimal(string: String(format: "%.8f", latest.amount)),
              rate > 0
        else {
            return nil
        }

        self.init(
            ticker: ticker,
            label: "RENDIMENTO",
            paymentDate: Date(timeIntervalSince1970: TimeInterval(latest.date)),
            lastDatePrior: nil,
            rate: rate
        )
    }
}
