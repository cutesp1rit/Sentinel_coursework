import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AuthSubmissionVerificationNoopCoverageTests {
    @Test
    func authSubmissionAndVerificationNoopBranchesStayStable() async {
        var state = AuthState()
        state.flow = .forgotPassword

        let store = TestStore(initialState: state) {
            AuthReducer()
        }

        await store.send(.submitTapped)
        await store.send(.verifyEmailCompleted("Verified")) {
            $0.errorMessage = nil
            $0.flow = .auth
            $0.mode = .login
            $0.registerStep = .email
            $0.isSubmitting = false
            $0.verificationToken = ""
            $0.statusMessage = "Verified"
        }
    }
}
