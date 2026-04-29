import SentinelUI
import SentinelCore
import SwiftUI
#if canImport(SafariServices)
import SafariServices
#endif

struct LegalDocumentsView: View {
    @State private var selectedDocument: LegalDocumentLink?

    var body: some View {
        List {
            ForEach(AppConfiguration.legalDocuments) { document in
                Button {
                    selectedDocument = document
                } label: {
                    HStack {
                        Text(document.kind.localizedTitle)
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
}

struct AuthLegalLinksView: View {
    @State private var selectedDocument: LegalDocumentLink?

    private let supportedKinds: [LegalDocumentLink.Kind] = [
        .privacyPolicy,
        .termsOfUse
    ]

    var body: some View {
        let documents = supportedKinds.compactMap { AppConfiguration.legalDocument(kind: $0) }

        HStack(spacing: AppSpacing.small) {
            ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                Button {
                    selectedDocument = document
                } label: {
                    Text(document.kind.localizedTitle)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)

                if index < documents.count - 1 {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.small)
        .sheet(item: $selectedDocument) { document in
            InAppDocumentView(url: document.url)
        }
    }
}

private extension LegalDocumentLink.Kind {
    var localizedTitle: String {
        switch self {
        case .privacyPolicy:
            return L10n.Profile.privacyPolicy
        case .termsOfUse:
            return L10n.Profile.termsOfUse
        case .personalDataConsent:
            return L10n.Profile.personalDataConsent
        case .attachmentProcessingNotice:
            return L10n.Profile.attachmentProcessingNotice
        case .privacyChoicesAndAccountDeletion:
            return L10n.Profile.privacyChoicesAndAccountDeletion
        }
    }
}

#if canImport(SafariServices)
struct InAppDocumentView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif
