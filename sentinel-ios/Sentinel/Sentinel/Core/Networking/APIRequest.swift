import Foundation

enum HTTPMethod: String {
    case delete = "DELETE"
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
}

struct APIRequest {
    var path: String
    var method: HTTPMethod
    var queryItems: [URLQueryItem] = []
    var body: Data?
    var bearerToken: String?
    var timeoutInterval: TimeInterval?

    nonisolated func urlRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError(code: "INVALID_URL", message: "Could not build request URL", details: path)
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError(code: "INVALID_URL", message: "Could not resolve request URL", details: path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.timeoutInterval = timeoutInterval ?? 60
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}
