import SafariServices
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var safariDestination: SafariDestination?
    private let reviewPromptGate = ReviewPromptGate()

    var body: some View {
        @Bindable var store = appStore

        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Text(appStore.session?.email ?? (appStore.session == nil ? "Not signed in" : "Signed in with Apple"))
                        Spacer()
                    }

                    Button(appStore.session == nil ? "Sign in" : "Sign out") {
                        if appStore.session == nil {
                            dismiss()
                            appStore.isShowingAuth = true
                        } else {
                            appStore.signOut()
                        }
                    }
                    .accessibilityLabel(appStore.session == nil ? "Sign in" : "Sign out")
                }

                Section("Appearance") {
                    Picker("Theme", selection: $store.theme) {
                        ForEach(ThemePreference.allCases) { theme in
                            Text(theme.display).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Reduce Motion", isOn: $store.reduceMotion)
                }

                Section("App") {
                    Button("How it works") {
                        dismiss()
                        appStore.isShowingTutorial = true
                    }
                    .accessibilityLabel("How it works")

                    Button("Clear history", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .accessibilityLabel("Clear history")

                    Button("Rate BuySell") {
                        requestReview()
                    }
                    .accessibilityLabel("Rate BuySell")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(Color.brand.mutedForeground)
                    }

                    Button("Privacy policy") {
                        safariDestination = URL(string: "https://buysell.ai/privacy").map(SafariDestination.init)
                    }
                    .accessibilityLabel("Privacy policy")

                    Button("Terms") {
                        safariDestination = URL(string: "https://buysell.ai/terms").map(SafariDestination.init)
                    }
                    .accessibilityLabel("Terms")
                }

                if appStore.session != nil {
                    Section("Danger zone") {
                        NavigationLink("Delete account") {
                            DeleteAccountView()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
            .confirmationDialog("Delete this listing? This can't be undone.", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) {
                    appStore.clearHistory()
                }
                .accessibilityLabel("Clear history")
                Button("Cancel", role: .cancel) {}
                    .accessibilityLabel("Cancel")
            }
            .sheet(item: $safariDestination) { destination in
                SafariView(url: destination.url)
            }
        }
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func requestReview() {
        guard reviewPromptGate.shouldRequestReview(for: appVersion) else {
            appStore.showToast("Thanks for rating BuySell.", style: .success)
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

private struct DeleteAccountView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var isDeletingAccount = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Delete account")
                .brandFont(.titleXL)
                .foregroundStyle(Color.brand.foreground)

            Text("Type DELETE to confirm.")
                .brandFont(.body)
                .foregroundStyle(Color.brand.mutedForeground)

            TextField("DELETE", text: $confirmation)
                .textInputAutocapitalization(.characters)
                .brandFont(.body)
                .padding(Spacing.md)
                .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))

            PrimaryPillButton(title: isDeletingAccount ? "Deleting…" : "Delete account") {
                guard isDeletingAccount == false else { return }
                isDeletingAccount = true
                Task {
                    let didDelete = await appStore.deleteAccount()
                    isDeletingAccount = false
                    if didDelete {
                        dismiss()
                    }
                }
            }
            .disabled(confirmation != "DELETE" || isDeletingAccount)

            Spacer()
        }
        .padding(Spacing.xl)
        .background(Color.brand.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
                    .accessibilityLabel("Close delete account")
            }
        }
    }
}

private struct SafariDestination: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
