import Foundation

enum BrapiError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case http(statusCode: Int, message: String?)
    case unauthorized(message: String?)
    case decoding(String)
    case api(message: String, code: String?)
    case featureUnavailable(message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Não foi possível montar a URL da brapi."
        case .invalidResponse:
            "A brapi retornou uma resposta inválida."
        case .http(let statusCode, let message):
            message ?? "A brapi retornou o status \(statusCode)."
        case .unauthorized(let message):
            message ?? "Token da brapi ausente ou inválido."
        case .decoding(let message):
            "Não foi possível ler os dados da brapi: \(message)"
        case .api(let message, _):
            message
        case .featureUnavailable(let message):
            message ?? "Este dado exige um plano pago da brapi."
        }
    }

    var isOptionalDataUnavailable: Bool {
        switch self {
        case .unauthorized, .featureUnavailable:
            true
        default:
            false
        }
    }
}
