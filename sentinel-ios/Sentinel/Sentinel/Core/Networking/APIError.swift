import Foundation

struct APIError: Error, Equatable {
    let code: String
    let message: String
    let details: String?
}

struct APIErrorDTO: Decodable {
    let code: String
    let message: String
    let details: String?
}

struct FastAPIErrorDTO: Decodable {
    let detail: Detail

    enum Detail: Decodable {
        case issues([FastAPIValidationIssue])
        case message(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let issues = try? container.decode([FastAPIValidationIssue].self) {
                self = .issues(issues)
            } else {
                self = .message(try container.decode(String.self))
            }
        }

        var userMessage: String {
            switch self {
            case let .issues(issues):
                return issues.first?.message ?? "Request validation failed."
            case let .message(message):
                return message
            }
        }
    }
}

struct FastAPIValidationIssue: Decodable {
    let message: String

    enum CodingKeys: String, CodingKey {
        case message = "msg"
    }
}
