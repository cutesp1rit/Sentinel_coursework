import Foundation
import Testing
@testable import Sentinel

@MainActor
struct APIRequestAndErrorTests {
    @Test
    func apiRequestBuildsRequestWithHeadersAndDefaults() throws {
        let payload = Data("body".utf8)
        let request = APIRequest(
            path: "events/",
            method: .post,
            queryItems: [URLQueryItem(name: "query", value: "value")],
            body: payload,
            bearerToken: "token",
            headers: ["X-Test": "1"],
            timeoutInterval: 12
        )

        let built = try request.urlRequest(baseURL: URL(string: "https://example.com/api/")!)
        let components = URLComponents(url: try #require(built.url), resolvingAgainstBaseURL: false)
        #expect(components?.path == "/api/events/")
        #expect(components?.queryItems == [URLQueryItem(name: "query", value: "value")])
        #expect(built.httpMethod == HTTPMethod.post.rawValue)
        #expect(built.httpBody == payload)
        #expect(built.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8")
        #expect(built.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(built.value(forHTTPHeaderField: "X-Test") == "1")
        #expect(built.timeoutInterval == 12)
    }

    @Test
    func fastAPIErrorDecodesBothDetailShapes() throws {
        let issuesData = Data("""
        {"detail":[{"msg":"Field is required"}]}
        """.utf8)
        let issues = try AppConfiguration.jsonDecoder.decode(FastAPIErrorDTO.self, from: issuesData)
        #expect(issues.detail.userMessage == "Field is required")

        let messageData = Data("""
        {"detail":"Unauthorized"}
        """.utf8)
        let message = try AppConfiguration.jsonDecoder.decode(FastAPIErrorDTO.self, from: messageData)
        #expect(message.detail.userMessage == "Unauthorized")

        let apiError = try AppConfiguration.jsonDecoder.decode(
            APIErrorDTO.self,
            from: Data(#"{"code":"BAD","message":"Nope","details":"extra"}"#.utf8)
        )
        #expect(apiError.code == "BAD")
        #expect(apiError.message == "Nope")
        #expect(apiError.details == "extra")
    }
}
