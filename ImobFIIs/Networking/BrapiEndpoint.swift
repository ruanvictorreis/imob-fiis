import Foundation

enum BrapiEndpoint: Sendable {
    case tickers(FIITickerQuery)
    case quote(symbol: String)
    case fiiIndicators(symbols: [String])
    case fiiDividends(symbols: [String])

    func urlRequest(baseURL: URL, token: String?) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw BrapiError.invalidURL
        }

        let items = queryItems
        if !items.isEmpty {
            components.queryItems = items
        }

        guard let url = components.url else {
            throw BrapiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private var path: String {
        switch self {
        case .tickers:
            "api/v2/tickers"
        case .quote(let symbol):
            "api/quote/\(symbol)"
        case .fiiIndicators:
            "api/v2/fii/indicators"
        case .fiiDividends:
            "api/v2/fii/dividends"
        }
    }

    private var queryItems: [URLQueryItem] {
        switch self {
        case .tickers(let query):
            query.urlQueryItems
        case .quote:
            []
        case .fiiIndicators(let symbols):
            [URLQueryItem(name: "symbols", value: symbols.joined(separator: ","))]
        case .fiiDividends(let symbols):
            fiiDividendsQueryItems(symbols: symbols)
        }
    }

    private func fiiDividendsQueryItems(symbols: [String]) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "symbols", value: symbols.joined(separator: ",")),
            URLQueryItem(name: "sortBy", value: "paymentDate"),
            URLQueryItem(name: "sortOrder", value: "desc"),
        ]

        if let startDate = Calendar(identifier: .gregorian).date(
            byAdding: .month,
            value: -6,
            to: Date()
        ) {
            items.append(URLQueryItem(name: "startDate", value: Self.yearMonthDay(from: startDate)))
        }

        return items
    }

    private static func yearMonthDay(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct FIITickerQuery: Sendable, Equatable {
    var search: String?
    var subsector: String?
    var subType: String = "fii"
    var page: Int = 1
    var limit: Int = 400
    var sortBy: String = "volume"
    var sortOrder: String = "desc"

    static let allFIIs = FIITickerQuery()
    static let allFiagros = FIITickerQuery(subType: "fi-agro")
    static let listedETFs = FIITickerQuery(subType: "etf")

    func with(subType: String) -> FIITickerQuery {
        var copy = self
        copy.subType = subType
        return copy
    }

    var urlQueryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "type", value: "fund"),
            URLQueryItem(name: "subType", value: subType),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sortBy", value: sortBy),
            URLQueryItem(name: "sortOrder", value: sortOrder),
        ]

        if let search, !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if let subsector, !subsector.isEmpty {
            items.append(URLQueryItem(name: "subsector", value: subsector))
        }
        return items
    }
}
