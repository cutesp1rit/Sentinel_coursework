import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AuthPasswordResetAndVerificationCoverageTests {
    @Test
    func resetPasswordSuccessAndFailureBranchesAreCovered() async {
        var successState = AuthState()
        successState.resetToken = "reset-token"
        successState.password = "password123"
        successState.confirmPassword = "password123"

        let successStore = TestStore(initialState: successState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.resetPassword = { token, password in
                #expect(token == "reset-token")
                #expect(password == "password123")
            }
        }

        await successStore.send(.resetPasswordTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await successStore.receive(.resetPasswordCompleted(L10n.Profile.passwordResetSucceeded)) {
            $0.errorMessage = nil
            $0.flow = .auth
            $0.mode = .login
            $0.registerStep = .email
            $0.isSubmitting = false
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
            $0.statusMessage = L10n.Profile.passwordResetSucceeded
        }

        var failureState = AuthState()
        failureState.resetToken = "reset-token"
        failureState.password = "password123"
        failureState.confirmPassword = "password123"

        let failureStore = TestStore(initialState: failureState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.resetPassword = { _, _ in
                struct SampleError: LocalizedError {
                    var errorDescription: String? { "Reset failed" }
                }
                throw SampleError()
            }
        }

        await failureStore.send(.resetPasswordTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await failureStore.receive(.submitFailed("Reset failed")) {
            $0.errorMessage = "Reset failed"
            $0.isSubmitting = false
        }
    }

    @Test
    func verificationAndResendAsyncBranchesCoverSuccessAndFailure() async {
        var resendState = AuthState()
        resendState.verificationRequiredEmail = "verify@example.com"

        let resendStore = TestStore(initialState: resendState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.resendVerification = { email in
                #expect(email == "verify@example.com")
                struct SampleError: LocalizedError {
                    var errorDescription: String? { "Resend failed" }
                }
                throw SampleError()
            }
        }

        await resendStore.send(.resendVerificationTapped) {
            $0.errorMessage = nil
            $0.isResendingVerification = true
            $0.statusMessage = nil
        }
        await resendStore.receive(.resendVerificationFailed("Resend failed")) {
            $0.errorMessage = "Resend failed"
            $0.isResendingVerification = false
        }

        var verifyState = AuthState()
        verifyState.verificationToken = "verify-token"

        let verifyStore = TestStore(initialState: verifyState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.verifyEmail = { _ in
                struct SampleError: LocalizedError {
                    var errorDescription: String? { "Verify failed" }
                }
                throw SampleError()
            }
        }

        await verifyStore.send(.verifyEmailTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await verifyStore.receive(.submitFailed("Verify failed")) {
            $0.errorMessage = "Verify failed"
            $0.isSubmitting = false
        }
    }

    @Test
    func retryVerificationLoginCoversValidationAndSuccess() async {
        let invalidStore = TestStore(initialState: AuthState()) {
            AuthReducer()
        }

        await invalidStore.send(.retryVerificationLoginTapped) {
            $0.errorMessage = L10n.Profile.emailRequired
        }

        var validState = AuthState()
        validState.email = "jane@example.com"
        validState.password = "password123"

        let session = Fixture.authenticatedSession(email: "jane.doe@example.com")
        let validStore = TestStore(initialState: validState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.login = { _, _ in Fixture.session() }
            $0.authClient.getMe = { _ in Fixture.user() }
            $0.sessionStorageClient.save = { _ in }
        }

        await validStore.send(.retryVerificationLoginTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await validStore.receive(.submitSucceeded(session)) {
            $0.email = "jane.doe@example.com"
            $0.errorMessage = nil
            $0.flow = .auth
            $0.mode = .login
            $0.registerStep = .email
            $0.isSubmitting = false
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
            $0.verificationToken = ""
            $0.session = session
            $0.statusMessage = nil
            $0.verificationRequiredEmail = nil
        }
    }
}
