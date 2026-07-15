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
                Section("Account".localized) {
                    HStack {
                        Text(appStore.session?.email ?? (appStore.session == nil ? "Not signed in" : "Signed in with Apple").localized)
                        Spacer()
                    }

                    Button((appStore.session == nil ? "Sign in" : "Sign out").localized) {
                        if appStore.session == nil {
                            dismiss()
                            appStore.isShowingAuth = true
                        } else {
                            appStore.signOut()
                        }
                    }
                    .accessibilityLabel((appStore.session == nil ? "Sign in" : "Sign out").localized)
                }

                Section("Appearance".localized) {
                    Picker("Theme".localized, selection: $store.theme) {
                        ForEach(ThemePreference.allCases) { theme in
                            Text(theme.display.localized).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Theme".localized)

                    Toggle("Reduce Motion".localized, isOn: $store.reduceMotion)
                        .accessibilityLabel("Reduce Motion".localized)

                    if ProcessInfo.processInfo.arguments.contains("--ui-testing-state-probe") {
                        Text(appStore.uiTestSettingsStateDescription)
                            .font(.caption2)
                            .foregroundStyle(Color.brand.mutedForeground)
                            .accessibilityIdentifier("SettingsStateProbe")
                    }
                }

                Section("App".localized) {
                    Button("How it works".localized) {
                        dismiss()
                        appStore.isShowingTutorial = true
                    }
                    .accessibilityLabel("How it works".localized)
                    .accessibilityIdentifier("Settings.HowItWorks")

                    Button("Clear history".localized, role: .destructive) {
                        showClearConfirmation = true
                    }
                    .accessibilityLabel("Clear history".localized)
                    .accessibilityIdentifier("Settings.ClearHistory")

                    Button("Rate BuySell".localized) {
                        requestReview()
                    }
                    .accessibilityLabel("Rate BuySell".localized)
                }

                Section("About".localized) {
                    HStack {
                        Text("Version".localized)
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(Color.brand.mutedForeground)
                    }

                    Button("Privacy policy".localized) {
                        safariDestination = URL(string: "https://buysell.ai/privacy").map(SafariDestination.init)
                    }
                    .accessibilityLabel("Privacy policy".localized)

                    Button("Terms".localized) {
                        safariDestination = URL(string: "https://buysell.ai/terms").map(SafariDestination.init)
                    }
                    .accessibilityLabel("Terms".localized)
                }

                if appStore.session != nil {
                    Section("Danger zone".localized) {
                        NavigationLink("Delete account".localized) {
                            DeleteAccountView()
                        }
                        .accessibilityLabel("Delete account".localized)
                        .accessibilityIdentifier("Settings.DeleteAccount")
                    }
                }
            }
            .navigationTitle("Settings".localized)
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
            .accessibilitySortPriority(1)
            .confirmationDialog("Clear all listing history? This can't be undone.".localized, isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear history".localized, role: .destructive) {
                    appStore.clearHistory()
                }
                .accessibilityLabel("Clear history".localized)
                .accessibilityIdentifier("Settings.ConfirmClearHistory")
                Button("Cancel".localized, role: .cancel) {}
                    .accessibilityLabel("Cancel".localized)
            }
            .sheet(item: $safariDestination) { destination in
                SafariView(url: destination.url)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close".localized) {
                        dismiss()
                    }
                    .accessibilityLabel("Close settings".localized)
                    .accessibilitySortPriority(2)
                }
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
            appStore.showToast("Thanks for rating BuySell.".localized, style: .success)
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
            Text("Delete account".localized)
                .brandFont(.titleXL)
                .foregroundStyle(Color.brand.foreground)
                .accessibilitySortPriority(4)

            Text("Type DELETE to confirm.".localized)
                .brandFont(.body)
                .foregroundStyle(Color.brand.mutedForeground)
                .accessibilitySortPriority(3)

            TextField("DELETE".localized, text: $confirmation)
                .textInputAutocapitalization(.characters)
                .brandFont(.body)
                .padding(Spacing.md)
                .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .accessibilityLabel("Delete confirmation".localized)
                .accessibilityHint("Type DELETE to confirm.".localized)
                .accessibilityIdentifier("Settings.DeleteAccountConfirmation")
                .accessibilitySortPriority(2)

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
            .accessibilityIdentifier("Settings.ConfirmDeleteAccount")
            .accessibilitySortPriority(1)

            Spacer()
        }
        .padding(Spacing.xl)
        .background(Color.brand.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close".localized) { dismiss() }
                    .accessibilityLabel("Close delete account".localized)
                    .accessibilitySortPriority(5)
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
