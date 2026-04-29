import Foundation

public struct APIError: Error, Equatable, Sendable {
    public let code: String
    public let message: String
    public let details: String?

    public init(code: String, message: String, details: String?) {
        self.code = code
        self.message = message
        self.details = details
    }
}

public struct APIErrorDTO: Decodable, Equatable, Sendable {
    public let code: String
    public let message: String
    public let details: String?

    public init(code: String, message: String, details: String?) {
        self.code = code
        self.message = message
        self.details = details
    }
}

public struct FastAPIErrorDTO: Decodable, Sendable {
    public let detail: Detail

    public enum Detail: Decodable, Sendable {
        case issues([FastAPIValidationIssue])
        case message(String)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let issues = try? container.decode([FastAPIValidationIssue].self) {
                self = .issues(issues)
            } else {
                self = .message(try container.decode(String.self))
            }
        }

        public var userMessage: String {
            switch self {
            case let .issues(issues):
                return issues.first?.message ?? "Request validation failed."
            case let .message(message):
                return message
            }
        }
    }
}

public struct FastAPIValidationIssue: Decodable, Equatable, Sendable {
    public let message: String

    enum CodingKeys: String, CodingKey {
        case message = "msg"
    }
}
