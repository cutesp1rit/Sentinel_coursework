import SwiftUI
import SentinelCore

extension View {
    @ViewBuilder
    func sentinelEmailField() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.username)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelTokenField() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}
