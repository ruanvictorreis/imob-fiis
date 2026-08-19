import Foundation

enum BrapiConfiguration {
    static let baseURL = URL(string: "https://brapi.dev")!

    static var apiToken: String? {
        if let token = ProcessInfo.processInfo.environment["BRAPI_API_TOKEN"], !token.isEmpty {
            return token
        }

        if let token = Bundle.main.object(forInfoDictionaryKey: "BRAPI_API_TOKEN") as? String,
           !token.isEmpty {
            return token
        }

        return nil
    }
}
