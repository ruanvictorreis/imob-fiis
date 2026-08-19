import Foundation

enum BrapiEndpoint: Sendable {
    case tickers(FIITickerQuery)
    case quote(symbol: String)
    case fiiIndicators(symbols: [String])

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
        }
    }
}

struct FIITickerQuery: Sendable, Equatable {
    var search: String? = nil
    var subsector: String? = nil
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
