import ComposableArchitecture
import Foundation

@ObservableState
struct SettingsState: Equatable {
    var accessToken: String? = nil
    var userEmail: String? = nil

    var defaultPromptTemplate = ""
    var isLoading = false
    var statusMessage: String?
}
