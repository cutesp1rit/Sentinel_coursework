import ComposableArchitecture
import SentinelCore
import Foundation

@Reducer
struct AuthReducer: Reducer {
    var body: some Reducer<AuthState, AuthAction> {
        Reduce { state, action in
            if let effect = handleInputActions(action, state: &state) {
                return effect
            }
            if let effect = handlePasswordResetActions(action, state: &state) {
                return effect
            }
            if let effect = handleSessionActions(action, state: &state) {
                return effect
            }
            if let effect = handleVerificationActions(action, state: &state) {
                return effect
            }
            if let effect = handleSubmissionActions(action, state: &state) {
                return effect
            }
            return .none
        }
    }
}
