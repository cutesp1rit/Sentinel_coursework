import Foundation

enum SettingsAction: Equatable {
    case defaultPromptChanged(String)
    case notificationsToggleChanged(Bool)
    case onAppear
    case promptSaved
    case savePromptTapped
    case settingsLoaded(AppSettings)
    case statusMessageUpdated(String?)
}
