import SafariServices
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var showDeleteAccount = false
    @State private var safariDestination: SafariDestination?
    private let reviewPromptGate = ReviewPromptGate()

    var body: some View {
        @Bindable var store = appStore

        NavigationStack {
            List {
                Section("Account".localized) {
                    SettingsRowLabel(
                        title: accountStatus,
                        systemImage: appStore.session == nil ? "person.crop.circle" : "person.crop.circle.badge.checkmark",
                        iconTint: Color.brand.primaryText
                    )
                    .accessibilityLabel(accountStatus)

                    SettingsActionRow(
                        title: appStore.session == nil ? "Sign in" : "Sign out",
                        systemImage: appStore.session == nil ? "arrow.right.circle.fill" : "rectangle.portrait.and.arrow.right",
                        iconTint: Color.brand.primaryText
                    ) {
                        if appStore.session == nil {
                            appStore.presentAuthAfterSettingsDismissal()
                        } else {
                            appStore.signOut()
                        }
                    }
                }

                Section("Appearance".localized) {
                    Picker("Theme".localized, selection: $store.theme) {
                        ForEach(ThemePreference.allCases) { theme in
                            Text(theme.display).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.brand.primary)
                    .accessibilityLabel("Theme".localized)
                    .onChange(of: store.theme) { _, _ in
                        Haptics.impact(.light)
                    }

                    Toggle("Reduce Motion".localized, isOn: $store.reduceMotion)
                        .tint(Color.brand.primary)
                        .accessibilityLabel("Reduce Motion".localized)
                        .onChange(of: store.reduceMotion) { _, _ in
                            Haptics.impact(.light)
                        }

                    if LaunchArguments.contains(LaunchArguments.uiTestingStateProbe) {
                        Text(appStore.uiTestSettingsStateDescription)
                            .font(.caption2)
                            .foregroundStyle(Color.brand.mutedForeground)
                            .accessibilityIdentifier("SettingsStateProbe")
                    }
                }

                Section("App".localized) {
                    SettingsActionRow(
                        title: "How it works",
                        systemImage: "questionmark.circle.fill",
                        iconTint: Color.brand.primaryText,
                        accessibilityIdentifier: "Settings.HowItWorks"
                    ) {
                        appStore.presentTutorialAfterSettingsDismissal()
                    }

                    SettingsActionRow(
                        title: "Clear history",
                        systemImage: "trash.fill",
                        iconTint: Color.brand.destructive,
                        titleTint: Color.brand.destructive,
                        accessibilityIdentifier: "Settings.ClearHistory",
                        role: .destructive
                    ) {
                        showClearConfirmation = true
                    }

                    SettingsActionRow(
                        title: "Rate BuySell",
                        systemImage: "star.fill",
                        iconTint: Color.brand.primaryText
                    ) {
                        requestReview()
                    }
                }

                Section("About".localized) {
                    SettingsRowLabel(
                        title: "Version",
                        systemImage: "info.circle.fill",
                        iconTint: Color.brand.primaryText,
                        value: versionString
                    )
                    .accessibilityLabel(String.localizedFormat("%@, %@", "Version".localized, versionString))

                    SettingsActionRow(
                        title: "Privacy policy",
                        systemImage: "hand.raised.fill",
                        iconTint: Color.brand.primaryText
                    ) {
                        safariDestination = AppStoreLinks.url(for: .privacyPolicy).map(SafariDestination.init)
                    }

                    SettingsActionRow(
                        title: "Terms",
                        systemImage: "doc.text.fill",
                        iconTint: Color.brand.primaryText
                    ) {
                        safariDestination = AppStoreLinks.url(for: .terms).map(SafariDestination.init)
                    }
                }

                if appStore.session != nil {
                    Section("Danger zone".localized) {
                        SettingsActionRow(
                            title: "Delete account",
                            systemImage: "person.crop.circle.badge.xmark",
                            iconTint: Color.brand.destructive,
                            titleTint: Color.brand.destructive,
                            accessibilityIdentifier: "Settings.DeleteAccount",
                            role: .destructive
                        ) {
                            showDeleteAccount = true
                        }
                    }
                }
            }
            .navigationTitle("Settings".localized)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
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
            .navigationDestination(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.impact(.light)
                        dismiss()
                    } label: {
                        Label("Close settings".localized, systemImage: "xmark")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Close settings".localized)
                    .accessibilitySortPriority(2)
                }
            }
        }
    }

    private var accountStatus: String {
        appStore.session?.email ?? (appStore.session == nil ? "Not signed in" : "Signed in with Apple").localized
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func requestReview() {
        guard reviewPromptGate.canRequestReview(for: appVersion) else {
            appStore.showToast("Thanks for rating BuySell.".localized, style: .success)
            return
        }
        guard let scene = reviewPromptScene else {
            appStore.showToast("Rating isn't available right now.".localized, style: .info)
            return
        }
        SKStoreReviewController.requestReview(in: scene)
        reviewPromptGate.markReviewRequested(for: appVersion)
    }

    private var reviewPromptScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

private struct SettingsActionRow: View {
    let title: String
    let systemImage: String
    var iconTint: Color
    var titleTint: Color = Color.brand.foreground
    var accessibilityIdentifier: String?
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role) {
            Haptics.impact(.light)
            action()
        } label: {
            SettingsRowLabel(
                title: title,
                systemImage: systemImage,
                iconTint: iconTint,
                titleTint: titleTint,
                showsDisclosureIndicator: true
            )
        }
        .buttonStyle(.automatic)
        .accessibilityLabel(Text(title.localized))
        .settingsAccessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    var iconTint: Color
    var titleTint: Color = Color.brand.foreground
    var value: String?
    var showsDisclosureIndicator = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.body.weight(.regular))
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            labelContent

            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var labelContent: some View {
        if let value, dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                titleText
                valueText(value)
            }

            Spacer(minLength: Spacing.sm)
        } else {
            Text(title.localized)
                .brandFont(.body)
                .foregroundStyle(titleTint)
                .lineLimit(2)
                .minimumScaleFactor(0.86)

            Spacer(minLength: Spacing.md)

            if let value {
                valueText(value)
            }
        }
    }

    private var titleText: some View {
        Text(title.localized)
            .brandFont(.body)
            .foregroundStyle(titleTint)
            .lineLimit(2)
            .minimumScaleFactor(0.86)
    }

    private func valueText(_ value: String) -> some View {
        Text(value)
            .brandFont(.caption)
            .foregroundStyle(Color.brand.mutedForeground)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.82)
    }
}

private extension View {
    @ViewBuilder
    func settingsAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

private struct DeleteAccountView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var confirmation = ""
    @State private var isDeletingAccount = false
    @State private var deleteAccountTask: Task<Void, Never>?
    @FocusState private var isConfirmationFocused: Bool

    var body: some View {
        List {
            Section {
                Text("Type DELETE to confirm.".localized)
                    .brandFont(.body)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .accessibilitySortPriority(3)

                TextField("DELETE".localized, text: $confirmation)
                    .textInputAutocapitalization(.characters)
                    .brandFont(.body)
                    .focused($isConfirmationFocused)
                    .focusedInputChrome(isFocused: isConfirmationFocused)
                    .accessibilityLabel("Delete confirmation".localized)
                    .accessibilityHint("Type DELETE to confirm.".localized)
                    .accessibilityIdentifier("Settings.DeleteAccountConfirmation")
                    .accessibilitySortPriority(2)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, bottomContentInset, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            deleteBottomAction
        }
        .background(Color.clear)
        .navigationTitle("Delete account".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isConfirmationFocused = true
        }
        .onDisappear {
            deleteAccountTask?.cancel()
            deleteAccountTask = nil
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.impact(.light)
                    dismiss()
                } label: {
                    Label("Close delete account".localized, systemImage: "xmark")
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Close delete account".localized)
                .accessibilitySortPriority(5)
            }
        }
    }

    private var deleteBottomAction: some View {
        Button(role: .destructive) {
            guard isDeletingAccount == false else { return }
            Haptics.impact(.light)
            isDeletingAccount = true
            deleteAccountTask = Task { @MainActor in
                let didDelete = await appStore.deleteAccount()
                guard Task.isCancelled == false else { return }
                deleteAccountTask = nil
                isDeletingAccount = false
                if didDelete {
                    dismiss()
                }
            }
        } label: {
            Label(isDeletingAccount ? "Deleting…".localized : "Delete account".localized, systemImage: "person.crop.circle.badge.xmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.brand.destructive)
        .disabled(confirmation != "DELETE" || isDeletingAccount)
        .accessibilityLabel((isDeletingAccount ? "Deleting…" : "Delete account").localized)
        .accessibilityIdentifier("Settings.ConfirmDeleteAccount")
        .accessibilitySortPriority(1)
        .frame(maxWidth: contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .background(.bar)
    }

    private var contentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 560 : .infinity
    }

    private var bottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 136 : 104
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
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
