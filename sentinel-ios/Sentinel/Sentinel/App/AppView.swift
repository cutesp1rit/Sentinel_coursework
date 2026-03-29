import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(L10n.App.title)
                    .font(.largeTitle.bold())

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(AppSpacing.large)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(L10n.App.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("App Shell") {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
