import Foundation

enum SettingsAction: Equatable {
    case defaultPromptChanged(String)
    case onAppear
    case promptSaved
    case savePromptTapped
    case settingsLoaded(AppSettings)
}
