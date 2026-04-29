import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AuthInputAndSessionCoverageTests {
    @Test
    func inputActionsMutateFieldsAndClearMessages() async {
        func makeState() -> AuthState {
            var state = AuthState()
            state.errorMessage = "error"
            state.statusMessage = "status"
            return state
        }

        let emailStore = TestStore(initialState: makeState()) { AuthReducer() }
        await emailStore.send(.emailChanged("jane@example.com")) {
            $0.email = "jane@example.com"
            $0.errorMessage = nil
            $0.statusMessage = nil
        }

        let passwordStore = TestStore(initialState: makeState()) { AuthReducer() }
        await passwordStore.send(.passwordChanged("password123")) {
            $0.password = "password123"
            $0.errorMessage = nil
            $0.statusMessage = nil
        }

        let confirmStore = TestStore(initialState: makeState()) { AuthReducer() }
        await confirmStore.send(.confirmPasswordChanged("password123")) {
            $0.confirmPassword = "password123"
            $0.errorMessage = nil
            $0.statusMessage = nil
        }

        let resetStore = TestStore(initialState: makeState()) { AuthReducer() }
        await resetStore.send(.resetTokenChanged("reset-token")) {
            $0.resetToken = "reset-token"
            $0.errorMessage = nil
            $0.statusMessage = nil
        }

        let verifyStore = TestStore(initialState: makeState()) { AuthReducer() }
        await verifyStore.send(.verificationTokenChanged("verify-token")) {
            $0.verificationToken = "verify-token"
            $0.errorMessage = nil
            $0.statusMessage = nil
        }

        let stepStore = TestStore(initialState: makeState()) { AuthReducer() }
        await stepStore.send(.registerStepChanged(.credentials)) {
            $0.registerStep = .credentials
            $0.errorMessage = nil
            $0.statusMessage = nil
        }
    }

    @Test
    func flowChangedToForgotPasswordAndModeResetBranchesClearRelevantFields() async {
        var initialState = AuthState()
        initialState.password = "password123"
        initialState.confirmPassword = "password123"
        initialState.resetToken = "reset-token"
        initialState.verificationToken = "verify-token"
        initialState.errorMessage = "error"
        initialState.statusMessage = "status"
        initialState.verificationRequiredEmail = "jane@example.com"

        let flowStore = TestStore(initialState: initialState) {
            AuthReducer()
        }

        await flowStore.send(.flowChanged(.verificationPending)) {
            $0.flow = .verificationPending
            $0.errorMessage = nil
            $0.statusMessage = nil
        }

        let forgotStore = TestStore(initialState: initialState) {
            AuthReducer()
        }
        await forgotStore.send(.forgotPasswordTapped) {
            $0.flow = .forgotPassword
            $0.errorMessage = nil
            $0.statusMessage = nil
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
        }

        let modeStore = TestStore(initialState: initialState) {
            AuthReducer()
        }
        await modeStore.send(.modeChanged(.login)) {
            $0.mode = .login
            $0.flow = .auth
            $0.registerStep = .email
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
            $0.verificationToken = ""
            $0.errorMessage = nil
            $0.statusMessage = nil
            $0.verificationRequiredEmail = nil
        }
    }

    @Test
    func restoreUnauthorizedClearsSessionAndRestoreFailureSetsMessage() async {
        let unauthorizedStore = TestStore(initialState: AuthState()) {
            AuthReducer()
        } withDependencies: {
            $0.sessionStorageClient.load = { Fixture.authenticatedSession() }
            $0.sessionStorageClient.clear = {}
            $0.authClient.getMe = { _ in
                throw APIError(code: "UNAUTHORIZED", message: "Expired", details: nil)
            }
        }

        await unauthorizedStore.send(.restoreRequested) {
            $0.hasAttemptedRestore = true
            $0.errorMessage = nil
            $0.isRestoring = true
        }
        await unauthorizedStore.receive(.restoredSession(nil)) {
            $0.email = ""
            $0.isRestoring = false
            $0.flow = .auth
            $0.mode = .login
            $0.registerStep = .email
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
            $0.verificationToken = ""
            $0.session = nil
        }

        let failedStore = TestStore(initialState: AuthState()) {
            AuthReducer()
        } withDependencies: {
            $0.sessionStorageClient.load = { Fixture.authenticatedSession() }
            $0.authClient.getMe = { _ in
                struct SampleError: LocalizedError {
                    var errorDescription: String? { "Restore failed" }
                }
                throw SampleError()
            }
        }

        await failedStore.send(.restoreRequested) {
            $0.hasAttemptedRestore = true
            $0.errorMessage = nil
            $0.isRestoring = true
        }
        await failedStore.receive(.restoreFailed("Restore failed")) {
            $0.errorMessage = "Restore failed"
            $0.isRestoring = false
        }
    }

    @Test
    func directCompletionAndFailureActionsUpdateAuthState() async {
        var state = AuthState()
        state.flow = .verificationPending
        state.isSubmitting = true
        state.isResendingVerification = true
        state.password = "password123"
        state.confirmPassword = "password123"
        state.resetToken = "reset"
        state.verificationToken = "verify"

        let store = TestStore(initialState: state) {
            AuthReducer()
        }

        await store.send(.resendVerificationFailed("Resend failed")) {
            $0.errorMessage = "Resend failed"
            $0.isResendingVerification = false
        }

        store.exhaustivity = .off

        await store.send(.resendVerificationCompleted("Sent")) {
            $0.errorMessage = nil
            $0.isResendingVerification = false
            $0.statusMessage = "Sent"
        }

        await store.send(.forgotPasswordCompleted("Reset mail sent")) {
            $0.errorMessage = nil
            $0.isSubmitting = false
            $0.statusMessage = "Reset mail sent"
        }

        await store.send(.resetPasswordCompleted("Done")) {
            $0.errorMessage = nil
            $0.flow = .auth
            $0.mode = .login
            $0.registerStep = .email
            $0.isSubmitting = false
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
            $0.statusMessage = "Done"
        }

        await store.send(.verificationRequired("jane@example.com", message: "Verify first")) {
            $0.errorMessage = nil
            $0.isSubmitting = false
            $0.flow = .verificationPending
            $0.verificationRequiredEmail = "jane@example.com"
            $0.statusMessage = "Verify first"
        }
    }
}
