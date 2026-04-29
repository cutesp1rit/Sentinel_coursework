import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AuthVerificationPasswordResetEdgeCoverageTests {
    @Test
    func verificationSuccessWithoutCredentialsAndPasswordResetValidationBranches() async {
        var verifyState = AuthState()
        verifyState.verificationToken = "verify-token"

        let verifyStore = TestStore(initialState: verifyState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.verifyEmail = { token in
                #expect(token == "verify-token")
            }
        }

        await verifyStore.send(.verifyEmailTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await verifyStore.receive(.verifyEmailCompleted(L10n.Profile.emailVerifiedStatus)) {
            $0.errorMessage = nil
            $0.flow = .auth
            $0.mode = .login
            $0.registerStep = .email
            $0.isSubmitting = false
            $0.verificationToken = ""
            $0.statusMessage = L10n.Profile.emailVerifiedStatus
        }

        let invalidResetStore = TestStore(initialState: AuthState()) {
            AuthReducer()
        }
        await invalidResetStore.send(.sendPasswordResetEmailTapped) {
            $0.errorMessage = L10n.Profile.emailRequired
        }
    }
}
