import Foundation
@testable import ImobFIIs

struct MockHTTPClient: HTTPPerforming {
    let data: Data
    let statusCode: Int

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
              )
        else {
            throw BrapiError.invalidResponse
        }
        return (data, response)
    }
}
