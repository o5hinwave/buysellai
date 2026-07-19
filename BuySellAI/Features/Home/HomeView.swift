import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pendingDeletion: HistoryEntry?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: Spacing.xl) {
                        header

                        VStack(spacing: Spacing.lg) {
                            Image("SigmaHero")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 176, height: 176)
                                .shadow(color: Color.brand.primary.opacity(0.35), radius: 30, x: 0, y: 12)
                                .accessibilityHidden(true)

                            VStack(spacing: Spacing.sm) {
                                Text("Sell anything in three taps.".localized)
                                    .brandFont(.display)
                                    .foregroundStyle(Color.brand.foreground)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.78)

                                Text("Snap a photo. Pick a marketplace. Copy your listing.".localized)
                                    .brandFont(.body)
                                    .foregroundStyle(Color.brand.mutedForeground)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                            }

                            VStack(spacing: Spacing.sm) {
                                PrimaryPillButton(
                                    title: "Snap to sell",
                                    systemImage: "camera.fill",
                                    maxFillWidth: heroContentMaxWidth,
                                    showsGlow: true
                                ) {
                                    appStore.startSnapFlow()
                                }
                                .accessibilityHint("Opens the camera".localized)

                            SecondaryPillButton(title: "How it works", maxFillWidth: heroContentMaxWidth) {
                                appStore.presentTutorial()
                            }
                        }
                        .nativeLiquidGlassControlGroup(spacing: Spacing.sm)
                        .padding(.top, Spacing.xs)
                    }
                        .frame(maxWidth: heroContentMaxWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.brand.background)
                    .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
                }

                Section {
                    if appStore.history.isEmpty {
                        EmptyHistoryView(maxWidth: sectionContentMaxWidth)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.brand.background)
                            .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg, bottom: Spacing.xl, trailing: Spacing.lg))
                    } else {
                        ForEach(appStore.history) { entry in
                            Button {
                                reopenHistoryEntry(entry)
                            } label: {
                                HistoryRow(entry: entry)
                            }
                            .buttonStyle(PressButtonStyle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    requestDeleteConfirmation(for: entry)
                                } label: {
                                    Label("Delete listing".localized, systemImage: "trash")
                                }
                                .tint(Color.brand.destructive)
                                .accessibilityLabel("Delete listing".localized)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.brand.background)
                            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.lg, bottom: Spacing.xs, trailing: Spacing.lg))
                            .accessibilityLabel(historyAccessibilityLabel(entry))
                        }
                    }
                } header: {
                    Text("Recent listings".localized)
                        .brandFont(.overline)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .textCase(.uppercase)
                        .tracking(0.88)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.sm)
                        .frame(maxWidth: sectionContentMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
            .contentMargins(.bottom, Spacing.xxxl, for: .scrollContent)
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

    private var heroContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 680 : .infinity
    }

    private var sectionContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 760 : .infinity
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    @ViewBuilder
    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    brandLockup

                    HStack(spacing: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            accountButton
                            settingsButton
                        }
                        .nativeLiquidGlassControlGroup(spacing: Spacing.sm)
                        Spacer(minLength: 0)
                    }
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    brandLockup

                    Spacer(minLength: Spacing.md)

                    HStack(spacing: Spacing.sm) {
                        accountButton
                        settingsButton
                    }
                    .nativeLiquidGlassControlGroup(spacing: Spacing.sm)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }

    private var brandLockup: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            BrandWordmark()
            Text("Snap · Pick · Sell".localized)
                .brandFont(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
        }
    }

    private var accountButton: some View {
        let title = (appStore.session == nil ? "Sign in" : "Sign out").localized

        return Button {
            handleAccountButtonTap()
        } label: {
            Text(title)
                .brandFont(.caption)
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .nativeStandardButtonBackground(tintOpacity: 0.7, strokeOpacity: 0.64)
        }
        .buttonStyle(PressButtonStyle())
        .tint(Color.brand.primary)
        .nativeGlassButtonStyle(.standard)
        .accessibilityLabel(title)
    }

    private var settingsButton: some View {
        IconCircleButton(
            systemImage: "gearshape.fill",
            accessibilityLabel: "Settings",
            size: 40,
            material: true,
            materialForeground: Color.brand.foreground,
            materialStroke: Color.brand.border,
            usesAccessibleMaterialStroke: true
        ) {
            appStore.presentSettings()
        }
        .frame(width: 44, height: 44)
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
}

private struct EmptyHistoryView: View {
    let maxWidth: CGFloat

    var body: some View {
        Text("Your past listings will show up here.".localized)
            .brandFont(.caption)
            .foregroundStyle(Color.brand.mutedForeground)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, Spacing.lg)
            .nativeMaterialPanel(cornerRadius: Radius.xl, tintOpacity: 0.78, strokeOpacity: 0.58)
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

private func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
