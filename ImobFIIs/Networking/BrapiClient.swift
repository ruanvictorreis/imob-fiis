import Foundation

protocol HTTPPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPPerforming {}

struct BrapiClient: Sendable {
    var baseURL: URL
    var token: String?
    var session: any HTTPPerforming
    var decoder: JSONDecoder

    init(
        baseURL: URL = BrapiConfiguration.baseURL,
        token: String? = BrapiConfiguration.apiToken,
        session: any HTTPPerforming = URLSession.shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        self.decoder = decoder
    }

    func send<Response: Decodable>(_ endpoint: BrapiEndpoint) async throws -> Response {
        let request = try endpoint.urlRequest(baseURL: baseURL, token: token)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BrapiError.invalidResponse
        }

        if let apiError = try? decoder.decode(BrapiAPIErrorBody.self, from: data), apiError.error == true {
            throw Self.makeError(statusCode: httpResponse.statusCode, body: apiError)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BrapiError.http(statusCode: httpResponse.statusCode, message: nil)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw BrapiError.decoding(String(describing: error))
        }
    }

    private static func makeError(statusCode: Int, body: BrapiAPIErrorBody) -> BrapiError {
        if statusCode == 401 || body.code == "MISSING_TOKEN" {
            return .unauthorized(message: body.message)
        }
        if body.code == "FEATURE_NOT_AVAILABLE" {
            return .featureUnavailable(message: body.message)
        }
        if let message = body.message {
            return .api(message: message, code: body.code)
        }
        return .http(statusCode: statusCode, message: body.message)
    }
}

struct BrapiAPIErrorBody: Decodable, Sendable {
    var error: Bool?
    var message: String?
    var code: String?
}
