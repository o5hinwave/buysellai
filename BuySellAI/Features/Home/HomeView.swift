import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var appStore
    @State private var pendingDeletion: HistoryEntry?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        startSnapFlow()
                    } label: {
                        SnapActionRow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Snap to sell".localized)
                    .accessibilityHint("Opens the camera".localized)

                    Button {
                        Haptics.impact(.light)
                        appStore.presentTutorial()
                    } label: {
                        HomeSecondaryActionRow(title: "How it works", systemImage: "questionmark.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("How it works".localized)
                } header: {
                    Text("Snap · Pick · Sell".localized)
                } footer: {
                    Text("Sell anything in three taps.".localized)
                }

                Section("Recent listings".localized) {
                    if appStore.history.isEmpty {
                        EmptyHistoryView()
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
                            .accessibilityLabel(historyAccessibilityLabel(entry))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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
}

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Your past listings will show up here.".localized)
                .brandFont(.body)
                .foregroundStyle(.secondary)
        }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 132)
            .accessibilityElement(children: .combine)
    }
}

private struct SnapActionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "camera.viewfinder")
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.brand.primaryForeground)
                .frame(width: 56, height: 56)
                .background(Color.brand.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Snap to sell".localized)
                    .brandFont(.bodyLg)
                    .foregroundStyle(.primary)

                Text("Snap a photo. Pick a marketplace. Copy your listing.".localized)
                    .brandFont(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
            }
            .layoutPriority(1)

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.right")
                .brandSymbol(.chevron)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }
}

private struct HomeSecondaryActionRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 28)
                .accessibilityHidden(true)

            Text(title.localized)
                .brandFont(.body)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .brandSymbol(.chevron)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

private func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
