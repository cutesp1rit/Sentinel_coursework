import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AuthSessionDirectCoverageTests {
    @Test
    func restoredSessionDirectActionPopulatesAndClearsFields() async {
        let session = Fixture.authenticatedSession(email: "jane@example.com")
        let store = TestStore(initialState: AuthState()) {
            AuthReducer()
        }

        await store.send(.restoredSession(session)) {
            $0.email = "jane@example.com"
            $0.isRestoring = false
            $0.flow = .auth
            $0.mode = .login
            $0.registerStep = .email
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
            $0.verificationToken = ""
            $0.session = session
        }
    }
}
