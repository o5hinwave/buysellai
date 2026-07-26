import SafariServices
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var showDeleteAccount = false
    @State private var showSellingPreferences = false
    @State private var safariDestination: SafariDestination?
    private let reviewPromptGate = ReviewPromptGate()

    var body: some View {
        @Bindable var store = appStore

        NavigationStack {
            List {
                accountSection
                appearanceSection(theme: $store.theme, reduceMotion: $store.reduceMotion)
                appSection
                aboutSection
                if appStore.session != nil {
                    dangerSection
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
            .navigationDestination(isPresented: $showSellingPreferences) {
                SellingPreferencesView()
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

    private var accountSection: some View {
        Section {
            SettingsRowLabel(
                title: accountStatus,
                systemImage: appStore.session == nil ? "person.crop.circle" : "person.crop.circle.badge.checkmark",
                iconTint: Color.brand.primaryText
            )
            .accessibilityLabel(accountStatus)

            SettingsRowLabel(
                title: "Free during early access",
                systemImage: "checkmark.seal.fill",
                iconTint: Color.brand.primaryText,
                value: appStore.earlyAccessStatusValue
            )
            .accessibilityLabel("Free during early access".localized)

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
        } header: {
            Text("Account".localized)
        } footer: {
            Text("BuySell is free during early access while we improve item identification, pricing research, and marketplace recommendations.".localized)
        }
    }

    private func appearanceSection(theme: Binding<ThemePreference>, reduceMotion: Binding<Bool>) -> some View {
        Section {
            Picker("Theme".localized, selection: theme) {
                ForEach(ThemePreference.allCases) { theme in
                    Text(theme.display).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color.brand.primary)
            .accessibilityLabel("Theme".localized)
            .onChange(of: appStore.theme) { _, _ in
                Haptics.impact(.light)
            }

            Toggle("Reduce Motion".localized, isOn: reduceMotion)
                .tint(Color.brand.primary)
                .accessibilityLabel("Reduce Motion".localized)
                .onChange(of: appStore.reduceMotion) { _, _ in
                    Haptics.impact(.light)
                }

            if LaunchArguments.contains(LaunchArguments.uiTestingStateProbe) {
                Text(appStore.uiTestSettingsStateDescription)
                    .font(.caption2)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .accessibilityIdentifier("SettingsStateProbe")
            }
        } header: {
            Text("Appearance".localized)
        }
    }

    private var appSection: some View {
        Section {
            SettingsActionRow(
                title: "How it works",
                systemImage: "questionmark.circle.fill",
                iconTint: Color.brand.primaryText,
                accessibilityIdentifier: "Settings.HowItWorks"
            ) {
                appStore.presentTutorialAfterSettingsDismissal()
            }

            if appStore.hasRememberedSellingPreferences {
                SettingsActionRow(
                    title: "Selling preferences",
                    systemImage: AppSymbol.Action.condition,
                    iconTint: Color.brand.primaryText,
                    accessibilityIdentifier: "Settings.SellingPreferences"
                ) {
                    showSellingPreferences = true
                }
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
        } header: {
            Text("App".localized)
        }
    }

    private var aboutSection: some View {
        Section {
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
        } header: {
            Text("About".localized)
        }
    }

    private var dangerSection: some View {
        Section {
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
        } header: {
            Text("Danger zone".localized)
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
                .brandSymbol(.rowIcon)
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            labelContent

            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .brandSymbol(.chevron)
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
                .font(.body)
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
            .font(.body)
            .foregroundStyle(titleTint)
            .lineLimit(2)
            .minimumScaleFactor(0.86)
    }

    private func valueText(_ value: String) -> some View {
        Text(value)
            .font(.caption)
            .foregroundStyle(Color.brand.mutedForeground)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.82)
    }
}

private struct SellingPreferencesView: View {
    @Environment(AppStore.self) private var appStore
    @State private var showClearAllConfirmation = false
    @State private var editingPreference: RememberedSellingPreferenceRow?

    var body: some View {
        List {
            Section {
                if preferenceRows.isEmpty {
                    ContentUnavailableView {
                        Label("No selling preferences".localized, systemImage: AppSymbol.Action.condition)
                    } description: {
                        Text("BuySell will ask again when it needs one.".localized)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .accessibilityElement(children: .combine)
                } else {
                    ForEach(preferenceRows) { row in
                        SellingPreferenceRow(row: row) {
                            Haptics.impact(.light)
                            editingPreference = row
                        } forget: {
                            appStore.forgetSellingPreference(for: row.marketplace)
                        }
                    }
                }
            } footer: {
                Text("BuySell uses these only to avoid asking the same marketplace question again.".localized)
            }

            if preferenceRows.isEmpty == false {
                Section {
                    Button(role: .destructive) {
                        Haptics.impact(.light)
                        showClearAllConfirmation = true
                    } label: {
                        SettingsRowLabel(
                            title: "Clear selling preferences",
                            systemImage: "trash.fill",
                            iconTint: Color.brand.destructive,
                            titleTint: Color.brand.destructive
                        )
                    }
                    .buttonStyle(.automatic)
                    .accessibilityLabel("Clear selling preferences".localized)
                    .accessibilityIdentifier("Settings.ClearSellingPreferences")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Selling preferences".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingPreference) { row in
            SellingPreferenceEditSheet(row: row)
        }
        .confirmationDialog("Clear selling preferences?".localized, isPresented: $showClearAllConfirmation, titleVisibility: .visible) {
            Button("Clear all".localized, role: .destructive) {
                appStore.clearRememberedSellingPreferences()
            }
            .accessibilityLabel("Clear all".localized)

            Button("Cancel".localized, role: .cancel) {}
                .accessibilityLabel("Cancel".localized)
        } message: {
            Text("BuySell will ask again when it needs one.".localized)
        }
    }

    private var preferenceRows: [RememberedSellingPreferenceRow] {
        let notes = appStore.rememberedSellingPreferences?.marketplaceNotes ?? [:]
        return Marketplace.activeRecommendationCases.compactMap { marketplace in
            guard let note = notes[marketplace]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  note.isEmpty == false
            else {
                return nil
            }
            return RememberedSellingPreferenceRow(marketplace: marketplace, note: note)
        }
    }
}

private struct RememberedSellingPreferenceRow: Identifiable {
    let marketplace: Marketplace
    let note: String

    var id: Marketplace {
        marketplace
    }
}

private struct SellingPreferenceRow: View {
    let row: RememberedSellingPreferenceRow
    let edit: () -> Void
    let forget: () -> Void

    var body: some View {
        Button {
            edit()
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                MarketplaceIcon(marketplace: row.marketplace, size: 36)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(row.marketplace.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                        .lineLimit(2)

                    Text(row.note)
                        .font(.caption)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 56)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Haptics.impact(.light)
                forget()
            } label: {
                Label("Forget".localized, systemImage: "trash")
            }
            .accessibilityLabel(String.localizedFormat("Forget %@ preference", row.marketplace.displayName))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", row.marketplace.displayName, row.note))
        .accessibilityHint("Opens preference editing.".localized)
    }
}

private struct SellingPreferenceEditSheet: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    let row: RememberedSellingPreferenceRow
    @State private var note: String
    @FocusState private var isNoteFocused: Bool

    init(row: RememberedSellingPreferenceRow) {
        self.row = row
        _note = State(initialValue: row.note)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Spacing.md) {
                        MarketplaceIcon(marketplace: row.marketplace, size: 36)
                        Text(row.marketplace.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.brand.foreground)
                    }
                    .frame(minHeight: 48)
                    .accessibilityElement(children: .combine)

                    TextField("Preference".localized, text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                        .focused($isNoteFocused)
                        .accessibilityLabel("Preference".localized)
                        .accessibilityIdentifier("Settings.SellingPreferenceEditor")
                } footer: {
                    Text("BuySell uses this only to pre-fill marketplace questions when it still fits.".localized)
                }

                Section {
                    Button(role: .destructive) {
                        Haptics.impact(.light)
                        appStore.forgetSellingPreference(for: row.marketplace)
                        dismiss()
                    } label: {
                        SettingsRowLabel(
                            title: "Forget this preference",
                            systemImage: "trash.fill",
                            iconTint: Color.brand.destructive,
                            titleTint: Color.brand.destructive
                        )
                    }
                    .accessibilityLabel(String.localizedFormat("Forget %@ preference", row.marketplace.displayName))
                    .accessibilityIdentifier("Settings.ForgetSellingPreference")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Edit preference".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel".localized)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
                        Haptics.impact(.light)
                        appStore.updateRememberedSellingPreference(note, for: row.marketplace)
                        dismiss()
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save selling preference".localized)
                    .accessibilityIdentifier("Settings.SaveSellingPreference")
                }
            }
            .onAppear {
                isNoteFocused = true
            }
        }
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
                    .font(.body)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .accessibilitySortPriority(3)

                TextField("DELETE".localized, text: $confirmation)
                    .textInputAutocapitalization(.characters)
                    .font(.body)
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
