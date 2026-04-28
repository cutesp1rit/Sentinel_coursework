import SwiftUI
#if canImport(SafariServices)
import SafariServices
#endif

struct EnvironmentSelectionView: View {
    let selectedEnvironment: AppEnvironment
    let onSelect: (AppEnvironment) -> Void

    var body: some View {
        List {
            ForEach(AppEnvironment.allCases) { environment in
                Button {
                    guard environment.isSelectable else { return }
                    onSelect(environment)
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        HStack(spacing: AppSpacing.medium) {
                            Text(title(for: environment))
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedEnvironment == environment {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text(detail(for: environment))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!environment.isSelectable)
                .opacity(environment.isSelectable ? 1 : AppOpacity.disabled)
            }
        }
        .navigationTitle(L10n.Profile.environmentTitle)
        .sentinelInlineNavigationTitle()
    }

    private func title(for environment: AppEnvironment) -> String {
        switch environment {
        case .local:
            return L10n.Profile.environmentLocal
        case .testing:
            return L10n.Profile.environmentTesting
        case .production:
            return L10n.Profile.environmentProduction
        }
    }

    private func detail(for environment: AppEnvironment) -> String {
        switch environment {
        case .local:
            return L10n.Profile.environmentLocalBody
        case .testing:
            return L10n.Profile.environmentTestingBody
        case .production:
            return L10n.Profile.environmentProductionBody
        }
    }
}

struct LegalDocumentsView: View {
    @State private var selectedDocument: LegalDocumentLink?

    var body: some View {
        List {
            ForEach(AppConfiguration.legalDocuments) { document in
                Button {
                    selectedDocument = document
                } label: {
                    HStack {
                        Text(title(for: document.kind))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(L10n.Profile.legalTitle)
        .sentinelInlineNavigationTitle()
        .sheet(item: $selectedDocument) { document in
            InAppDocumentView(url: document.url)
        }
    }

    private func title(for kind: LegalDocumentLink.Kind) -> String {
        switch kind {
        case .privacyPolicy:
            return L10n.Profile.privacyPolicy
        case .termsOfUse:
            return L10n.Profile.termsOfUse
        case .personalDataConsent:
            return L10n.Profile.personalDataConsent
        case .attachmentProcessingNotice:
            return L10n.Profile.attachmentProcessingNotice
        }
    }
}

#if canImport(SafariServices)
private struct InAppDocumentView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif
