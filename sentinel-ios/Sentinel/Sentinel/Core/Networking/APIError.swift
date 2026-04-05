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
