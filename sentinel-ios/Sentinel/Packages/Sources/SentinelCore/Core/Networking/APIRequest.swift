import Foundation

public enum HTTPMethod: String, Sendable {
    case delete = "DELETE"
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
}

public struct APIRequest: Sendable {
    public var path: String
    public var method: HTTPMethod
    public var queryItems: [URLQueryItem] = []
    public var body: Data?
    public var bearerToken: String?
    public var headers: [String: String] = [:]
    public var contentType: String? = "application/json; charset=utf-8"
    public var accept: String? = "application/json"
    public var timeoutInterval: TimeInterval?

    public init(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        bearerToken: String? = nil,
        headers: [String: String] = [:],
        contentType: String? = "application/json; charset=utf-8",
        accept: String? = "application/json",
        timeoutInterval: TimeInterval? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.bearerToken = bearerToken
        self.headers = headers
        self.contentType = contentType
        self.accept = accept
        self.timeoutInterval = timeoutInterval
    }

    public nonisolated func urlRequest(baseURL: URL) throws -> URLRequest {
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
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        return request
    }
}
