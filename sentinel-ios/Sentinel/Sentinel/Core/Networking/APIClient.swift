import ComposableArchitecture
import Foundation

struct APIClient {
    var send: @Sendable (APIRequest) async throws -> Data
}

private final class RedirectPreservingSessionDelegate: NSObject, URLSessionTaskDelegate {
    static let shared = RedirectPreservingSessionDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let originalURL = task.originalRequest?.url,
              let redirectedURL = request.url,
              originalURL.scheme == redirectedURL.scheme,
              originalURL.host == redirectedURL.host else {
            completionHandler(request)
            return
        }

        guard let authorization = task.originalRequest?.value(forHTTPHeaderField: "Authorization"),
              request.value(forHTTPHeaderField: "Authorization") == nil else {
            completionHandler(request)
            return
        }

        var redirectedRequest = request
        redirectedRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
        completionHandler(redirectedRequest)
    }
}

private let apiURLSession: URLSession = {
    URLSession(
        configuration: .default,
        delegate: RedirectPreservingSessionDelegate.shared,
        delegateQueue: nil
    )
}()

nonisolated func liveAPISend(_ request: APIRequest) async throws -> Data {
    let urlRequest = try await request.urlRequest(baseURL: AppConfiguration.apiBaseURL)
    let (data, response) = try await apiURLSession.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError(code: "INVALID_RESPONSE", message: "Expected HTTP response", details: nil)
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
        let error = await MainActor.run {
            if let errorDTO = try? AppConfiguration.jsonDecoder.decode(APIErrorDTO.self, from: data) {
                return APIError(
                    code: errorDTO.code,
                    message: errorDTO.message,
                    details: errorDTO.details
                )
            }

            if let fastAPIError = try? AppConfiguration.jsonDecoder.decode(FastAPIErrorDTO.self, from: data) {
                return APIError(
                    code: "HTTP_\(httpResponse.statusCode)",
                    message: fastAPIError.detail.userMessage,
                    details: nil
                )
            }

            if let fallbackMessage = String(data: data, encoding: .utf8),
               !fallbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return APIError(
                    code: "HTTP_\(httpResponse.statusCode)",
                    message: fallbackMessage,
                    details: nil
                )
            }

            return APIError(
                code: "HTTP_\(httpResponse.statusCode)",
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                details: nil
            )
        }

        throw error
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
