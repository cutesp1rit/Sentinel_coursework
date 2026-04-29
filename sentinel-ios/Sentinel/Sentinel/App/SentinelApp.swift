import SwiftUI
import SentinelCore

@main
struct SentinelApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                EmptyView()
            } else {
                ContentView()
            }
        }
    }
}
