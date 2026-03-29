import Foundation

enum AppConfiguration {
    nonisolated(unsafe) static let apiBaseURL = URL(string: "http://localhost:8000/api/v1")!

    nonisolated(unsafe) static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    nonisolated(unsafe) static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
