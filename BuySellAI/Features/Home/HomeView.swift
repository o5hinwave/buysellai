import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var appStore
    @State private var pendingDeletion: HistoryEntry?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HomeHeroSection(
                        startSnapFlow: startSnapFlow,
                        showTutorial: {
                            Haptics.impact(.light)
                            appStore.presentTutorial()
                        }
                    )
                }
                .listRowInsets(EdgeInsets(top: Spacing.lg, leading: Spacing.lg, bottom: Spacing.xl, trailing: Spacing.lg))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section("Saved listings".localized) {
                    historySectionContent
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
            .contentMargins(.bottom, Spacing.xxxl, for: .scrollContent)
            .navigationTitle("BuySell.".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandWordmark(size: .regular)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    accountButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
            .refreshable {
                await appStore.loadHistory()
            }
            .confirmationDialog(
                "Delete this listing? This can't be undone.".localized,
                isPresented: deleteConfirmationBinding,
                titleVisibility: .visible
            ) {
                Button("Delete listing".localized, role: .destructive) {
                    confirmDelete()
                }
                .accessibilityLabel("Delete listing".localized)

                Button("Cancel".localized, role: .cancel) {
                    pendingDeletion = nil
                }
                .accessibilityLabel("Cancel".localized)
            }
        }
    }

    private func startSnapFlow() {
        Haptics.impact(.medium)
        appStore.startSnapFlow()
    }

    private var accountButton: some View {
        Button {
            handleAccountButtonTap()
        } label: {
            Text(accountButtonTitle.localized)
        }
        .accessibilityLabel(accountButtonTitle.localized)
    }

    private var accountButtonTitle: String {
        appStore.session == nil ? "Sign in" : "Sign out"
    }

    private var settingsButton: some View {
        Button {
            Haptics.impact(.light)
            appStore.presentSettings()
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings".localized)
    }

    private func handleAccountButtonTap() {
        Haptics.impact(.light)
        if appStore.session == nil {
            appStore.presentAuth()
        } else {
            appStore.signOut()
        }
    }

    private func historyAccessibilityLabel(_ entry: HistoryEntry) -> String {
        HistoryAccessibilityText.rowLabel(for: entry, relativeDate: relativeDate(entry.createdAt))
    }

    private func reopenHistoryEntry(_ entry: HistoryEntry) {
        Haptics.impact(.light)
        appStore.reopenListing(entry)
    }

    private func requestDeleteConfirmation(for entry: HistoryEntry) {
        Haptics.impact(.light)
        pendingDeletion = entry
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    pendingDeletion = nil
                }
            }
        )
    }

    private func confirmDelete() {
        guard let pendingDeletion else { return }
        HistoryDeletionFeedback.perform()
        appStore.deleteHistory(pendingDeletion, emitsFeedback: false)
        self.pendingDeletion = nil
    }

    @ViewBuilder
    private var historySectionContent: some View {
        if isInitialHistoryLoading {
            HistoryLoadingView()
                .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else {
            if let historySyncFailureMessage {
                HistorySyncFailureRow(message: historySyncFailureMessage) {
                    retryHistorySync()
                }
                .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg, bottom: Spacing.sm, trailing: Spacing.lg))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if appStore.history.isEmpty {
                if historySyncFailureMessage == nil {
                    EmptyHistoryView()
                        .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                historyRows
            }
        }
    }

    private var historyRows: some View {
        ForEach(appStore.history) { entry in
            Button {
                reopenHistoryEntry(entry)
            } label: {
                HistoryRow(entry: entry)
            }
            .buttonStyle(PressButtonStyle())
            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    requestDeleteConfirmation(for: entry)
                } label: {
                    Label("Delete listing".localized, systemImage: "trash")
                }
                .tint(Color.brand.destructive)
                .accessibilityLabel("Delete listing".localized)
            }
            .accessibilityLabel(historyAccessibilityLabel(entry))
        }
    }

    private var isInitialHistoryLoading: Bool {
        guard case .loading = appStore.historySyncState else { return false }
        return appStore.history.isEmpty
    }

    private var historySyncFailureMessage: String? {
        guard case .failed(let message) = appStore.historySyncState else { return nil }
        return message
    }

    private func retryHistorySync() {
        Haptics.impact(.light)
        Task {
            await appStore.loadHistory()
        }
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No saved listings yet".localized, systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Ready when you are.".localized)
        }
        .frame(maxWidth: .infinity, minHeight: 116)
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: Spacing.md) {
                    SkeletonLine(height: 56, width: 56)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SkeletonLine(width: 160)
                        SkeletonLine(height: 12, width: 220)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityLabel("Loading recent listings".localized)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct HistorySyncFailureRow: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        Button {
            retry()
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                Image(systemName: "arrow.clockwise.circle")
                    .brandSymbol(.rowIcon)
                    .foregroundStyle(Color.brand.destructive)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Couldn't update listings".localized)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: Spacing.sm)

                Text("Try again".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(String.localizedFormat("%@, %@, %@", "Couldn't update listings".localized, message, "Try again".localized))
        .accessibilityHint("Checks for your latest saved listings".localized)
    }
}

private struct HomeHeroSection: View {
    let startSnapFlow: () -> Void
    let showTutorial: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: heroSpacing) {
            HomeHeroVisual()
                .padding(.top, Spacing.sm)

            VStack(spacing: Spacing.sm) {
                Text("Snap · Pick · Sell".localized)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.brand.primaryText)
                    .multilineTextAlignment(.center)

                Text("Sell anything in three taps.".localized)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.brand.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .minimumScaleFactor(0.74)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Snap a photo. Pick a marketplace. Copy your listing.".localized)
                    .font(.body)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 430)

            HomePromiseStrip()

            primaryAction
                .padding(.top, Spacing.xs)

            Button {
                showTutorial()
            } label: {
                Label("How it works".localized, systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity, minHeight: secondaryActionHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("How it works".localized)
            .accessibilityHint("Shows the first-use guide.".localized)

        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var primaryAction: some View {
        Button {
            startSnapFlow()
        } label: {
            Label("Snap to sell".localized, systemImage: "camera.viewfinder")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: primaryActionHeight)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.brand.primary)
        .accessibilityLabel("Snap to sell".localized)
        .accessibilityHint("Opens the camera".localized)
    }

    private var heroSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Spacing.lg : Spacing.xl
    }

    private var primaryActionHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 64 : 56
    }

    private var secondaryActionHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 58 : 50
    }
}

private struct HomeHeroVisual: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color.brand.primaryMuted)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(Color.brand.border.opacity(0.72), lineWidth: 1)
                }

            Image(systemName: "camera.viewfinder")
                .brandSymbol(.heroIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)

            VStack {
                HStack {
                    Image(systemName: "sparkles")
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                }
                Spacer()
                HStack {
                    Image(systemName: "tag")
                    Spacer()
                    Image(systemName: "checkmark.circle")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brand.primaryText.opacity(0.72))
            .padding(Spacing.md)
            .accessibilityHidden(true)
        }
        .frame(width: 132, height: 132)
        .accessibilityHidden(true)
    }
}

private struct HomePromiseStrip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.xs) {
                    promiseItems
                }
            } else {
                HStack(spacing: Spacing.xs) {
                    promiseItems
                }
            }
        }
        .padding(Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.brand.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Color.brand.border.opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step 1, take a photo. Step 2, pick a place. Step 3, copy the listing.".localized)
    }

    @ViewBuilder
    private var promiseItems: some View {
        HomePromiseItem(stepNumber: "1", title: "Take photo", systemImage: "camera")
        HomePromiseItem(stepNumber: "2", title: "Pick place", systemImage: "mappin.and.ellipse")
        HomePromiseItem(stepNumber: "3", title: "Copy listing", systemImage: "doc.on.clipboard")
    }
}

private struct HomePromiseItem: View {
    let stepNumber: String
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(stepNumber)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.brand.primaryMuted))

            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(title.localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.foregroundSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.horizontal, Spacing.xs)
    }
}

private func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
