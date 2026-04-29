import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AuthReducerFlowTests {
    @Test
    func modeAndFlowTransitionsResetRelevantFields() async {
        var initialState = AuthState()
        initialState.password = "secret"
        initialState.confirmPassword = "confirm"
        initialState.resetToken = "reset"
        initialState.verificationToken = "verify"
        initialState.verificationRequiredEmail = "jane@example.com"
        initialState.statusMessage = "status"
        initialState.errorMessage = "error"

        let store = TestStore(initialState: initialState) {
            AuthReducer()
        }

        await store.send(.modeChanged(.register)) {
            $0.mode = .register
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

        await store.send(.forgotPasswordTapped) {
            $0.flow = .forgotPassword
            $0.errorMessage = nil
            $0.statusMessage = nil
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
        }

        await store.send(.flowChanged(.auth)) {
            $0.flow = .auth
            $0.errorMessage = nil
            $0.statusMessage = nil
            $0.registerStep = .email
            $0.password = ""
            $0.confirmPassword = ""
            $0.resetToken = ""
            $0.verificationToken = ""
        }
    }

    @Test
    func submitTappedValidatesLoginAndRegistrationBranches() async {
        let store = TestStore(initialState: AuthState()) {
            AuthReducer()
        }

        await store.send(.submitTapped) {
            $0.errorMessage = L10n.Profile.emailRequired
        }

        await store.send(.emailChanged("jane@example.com")) {
            $0.email = "jane@example.com"
            $0.errorMessage = nil
            $0.statusMessage = nil
        }

        await store.send(.submitTapped) {
            $0.errorMessage = L10n.Profile.passwordRequired
        }

        await store.send(.modeChanged(.register)) {
            $0.mode = .register
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

        await store.send(.submitTapped) {
            $0.registerStep = .credentials
            $0.errorMessage = nil
        }
    }

    @Test
    func resetVerifyAndResendValidateInputs() async {
        let store = TestStore(initialState: AuthState()) {
            AuthReducer()
        }

        await store.send(.resetPasswordTapped) {
            $0.errorMessage = L10n.Profile.resetTokenRequired
        }

        await store.send(.verifyEmailTapped) {
            $0.errorMessage = L10n.Profile.verificationTokenRequired
        }

        await store.send(.resendVerificationTapped) {
            $0.errorMessage = L10n.Profile.emailRequired
        }
    }

    @Test
    func restoreRequestedWithNoStoredSessionFinishesCleanly() async {
        let store = TestStore(initialState: AuthState()) {
            AuthReducer()
        } withDependencies: {
            $0.sessionStorageClient.load = { nil }
        }

        await store.send(.restoreRequested) {
            $0.hasAttemptedRestore = true
            $0.errorMessage = nil
            $0.isRestoring = true
        }

        await store.receive(.restoredSession(nil)) {
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
    }

    @Test
    func sendPasswordResetEmailSuccessAndVerificationRequiredBranches() async {
        var initialState = AuthState()
        initialState.email = "jane@example.com"

        let resetStore = TestStore(initialState: initialState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.forgotPassword = { email in
                #expect(email == "jane@example.com")
            }
        }

        await resetStore.send(.sendPasswordResetEmailTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await resetStore.receive(.forgotPasswordCompleted(L10n.Profile.passwordResetEmailSent)) {
            $0.errorMessage = nil
            $0.isSubmitting = false
            $0.statusMessage = L10n.Profile.passwordResetEmailSent
        }

        var loginState = AuthState()
        loginState.email = "jane@example.com"
        loginState.password = "password123"
        let loginStore = TestStore(initialState: loginState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.login = { _, _ in
                throw APIError(code: "FORBIDDEN", message: "Please verify email", details: nil)
            }
        }

        await loginStore.send(.submitTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await loginStore.receive(.verificationRequired("jane@example.com", message: "Please verify email")) {
            $0.errorMessage = nil
            $0.isSubmitting = false
            $0.flow = .verificationPending
            $0.verificationRequiredEmail = "jane@example.com"
            $0.statusMessage = "Please verify email"
        }
    }

    @Test
    func loginSuccessVerifySuccessAndResendSuccessFlows() async {
        var loginState = AuthState()
        loginState.email = "jane@example.com"
        loginState.password = "password123"

        let authenticated = Fixture.authenticatedSession(email: "jane.doe@example.com")
        let loginStore = TestStore(initialState: loginState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.login = { _, _ in Fixture.session() }
            $0.authClient.getMe = { _ in Fixture.user() }
            $0.sessionStorageClient.save = { _ in }
        }

        await loginStore.send(.submitTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await loginStore.receive(.submitSucceeded(authenticated)) {
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
            $0.session = authenticated
            $0.statusMessage = nil
            $0.verificationRequiredEmail = nil
        }

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

        var resendState = AuthState()
        resendState.email = "jane@example.com"
        let resendStore = TestStore(initialState: resendState) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.resendVerification = { email in
                #expect(email == "jane@example.com")
            }
        }

        await resendStore.send(.resendVerificationTapped) {
            $0.errorMessage = nil
            $0.isResendingVerification = true
            $0.statusMessage = nil
        }
        await resendStore.receive(.resendVerificationCompleted(L10n.Profile.verificationEmailResent)) {
            $0.errorMessage = nil
            $0.isResendingVerification = false
            $0.statusMessage = L10n.Profile.verificationEmailResent
        }
    }

    @Test
    func registrationCredentialsBranchCanSucceedImmediately() async {
        var state = AuthState()
        state.mode = .register
        state.registerStep = .credentials
        state.email = "jane@example.com"
        state.password = "password123"
        state.confirmPassword = "password123"

        let authenticated = Fixture.authenticatedSession(email: "jane.doe@example.com")
        let store = TestStore(initialState: state) {
            AuthReducer()
        } withDependencies: {
            $0.authClient.register = { _, _, _ in Fixture.user() }
            $0.authClient.login = { _, _ in Fixture.session() }
            $0.sessionStorageClient.save = { _ in }
        }

        await store.send(.submitTapped) {
            $0.errorMessage = nil
            $0.isSubmitting = true
            $0.statusMessage = nil
        }
        await store.receive(.submitSucceeded(authenticated)) {
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
            $0.session = authenticated
            $0.statusMessage = nil
            $0.verificationRequiredEmail = nil
        }
    }
}
