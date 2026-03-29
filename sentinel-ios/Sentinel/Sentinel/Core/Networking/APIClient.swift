import ComposableArchitecture
import Foundation

struct APIClient {
    var send: @Sendable (APIRequest) async throws -> Data
}

nonisolated func liveAPISend(_ request: APIRequest) async throws -> Data {
    let urlRequest = try request.urlRequest(baseURL: AppConfiguration.apiBaseURL)
    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError(code: "INVALID_RESPONSE", message: "Expected HTTP response", details: nil)
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
        let errorDTO = try await MainActor.run {
            try? AppConfiguration.jsonDecoder.decode(APIErrorDTO.self, from: data)
        }

        throw APIError(
            code: errorDTO?.code ?? "HTTP_\(httpResponse.statusCode)",
            message: errorDTO?.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
            details: errorDTO?.details
        )
    }

    return data
}

extension APIClient: DependencyKey {
    static let liveValue = APIClient(send: liveAPISend)
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}
