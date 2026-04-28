import Foundation
import Testing
@testable import Sentinel

@MainActor
struct SessionModelTests {
    @Test
    func sessionModelsRoundTrip() throws {
        let authenticated = Fixture.authenticatedSession()
        #expect(authenticated.session == Fixture.session())

        let encoded = try AppConfiguration.jsonEncoder.encode(authenticated)
        let decoded = try AppConfiguration.jsonDecoder.decode(AuthenticatedSession.self, from: encoded)
        #expect(decoded == authenticated)
    }
}
