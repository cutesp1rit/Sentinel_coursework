import Foundation
import SentinelCore

extension HomeState {
    var displayName: String {
        guard let userEmail, !userEmail.isEmpty else {
            return "Sentinel"
        }

        let localPart = userEmail.split(separator: "@").first.map(String.init) ?? userEmail
        return localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var currentDateText: String {
        Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }
}
