import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(AppStore.self) private var appStore
    @State private var pendingDeletion: HistoryEntry?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HomeCameraHeroMark(startSnapFlow: startSnapFlow)
                }
                .listRowInsets(EdgeInsets(top: Spacing.xl, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    HomeStepRow(number: 1, title: "Snap it", detail: "Take one photo.", systemImage: "camera.viewfinder")
                    HomeStepRow(number: 2, title: "Answer tiny questions", detail: "Only what you know.", systemImage: "text.bubble")
                    HomeStepRow(number: 3, title: "Copy the post", detail: "BuySell picks the place and writes it.", systemImage: "doc.on.doc")
                    HomeHowItWorksRow {
                        Haptics.impact(.light)
                        appStore.presentTutorial()
                    }
                } header: {
                    Text("1 · 2 · 3".localized)
                } footer: {
                    Text("No selling skills needed.".localized)
                }

                if shouldShowHistorySection {
                    Section("Saved listings".localized) {
                        historySectionContent
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .contentMargins(.bottom, Spacing.xxxl, for: .scrollContent)
            .navigationTitle("BuySell.".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandWordmark(size: .regular, periodColor: Color.brand.foregroundSecondary)
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
        .tint(Color.brand.foreground)
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
        .tint(Color.brand.foreground)
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

    private var shouldShowHistorySection: Bool {
        isInitialHistoryLoading || historySyncFailureMessage != nil || appStore.history.isEmpty == false
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

private struct HomeCameraHeroMark: View {
    let startSnapFlow: () -> Void

    var body: some View {
        Button {
            startSnapFlow()
        } label: {
            cardContent
            .frame(maxWidth: .infinity, minHeight: 178)
            .contentShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel("Snap to sell".localized)
        .accessibilityHint("Opens the camera".localized)
    }

    private var cardContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(cardFill)
                .overlay(alignment: .topLeading) {
                    cardTopLine
                        .padding(Spacing.lg)
                }
                .overlay(alignment: .center) {
                    Image(systemName: "camera.viewfinder")
                        .brandSymbol(.heroIcon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.brand.foreground)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Snap to sell".localized)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.brand.foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text("Point. Shoot. Done.".localized)
                            .font(.subheadline)
                            .foregroundStyle(Color.brand.foregroundSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .padding(Spacing.lg)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 22, y: 10)
        }
    }

    private var cardTopLine: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            Text("BuySell".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.foregroundSecondary)
            Circle()
                .fill(Color.brand.primary)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)
        }
    }

    private var cardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color(uiColor: .secondarySystemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

}

private struct HomeStepRow: View {
    let number: Int
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.brand.primaryMuted)
                Text(verbatim: "\(number)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.brand.primaryText)
                    .monospacedDigit()
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title.localized)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                Text(detail.localized)
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Image(systemName: systemImage)
                .brandSymbol(.controlIcon)
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%d. %@. %@", number, title.localized, detail.localized))
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
                    .foregroundStyle(Color.brand.foreground)
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

private struct HomeHowItWorksRow: View {
    let showTutorial: () -> Void

    var body: some View {
        Button {
            showTutorial()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "questionmark.circle")
                    .brandSymbol(.controlIcon)
                    .foregroundStyle(Color.brand.foreground)
                    .frame(width: 34, height: 34)
                    .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("How it works".localized)
                        .font(.body)
                        .foregroundStyle(Color.brand.foreground)

                    Text("Take photo, pick place, copy listing.".localized)
                        .font(.subheadline)
                        .foregroundStyle(Color.brand.foregroundSecondary)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .brandSymbol(.smallChevron)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("How it works".localized)
        .accessibilityHint("Shows the first-use guide.".localized)
    }
}

private func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
