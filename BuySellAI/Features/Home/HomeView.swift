import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var appStore
    @State private var pendingDeletion: HistoryEntry?

    var body: some View {
        @Bindable var store = appStore

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
                                PrimaryPillButton(title: "Snap to sell", systemImage: "camera.fill", showsGlow: true) {
                                    appStore.startSnapFlow()
                                }
                                .accessibilityHint("Opens the camera".localized)

                                SecondaryPillButton(title: "How it works") {
                                    store.isShowingTutorial = true
                                }
                            }
                            .padding(.top, Spacing.xs)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.brand.background)
                    .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
                }

                Section {
                    if appStore.history.isEmpty {
                        EmptyHistoryView()
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.brand.background)
                            .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg, bottom: Spacing.xl, trailing: Spacing.lg))
                    } else {
                        ForEach(appStore.history) { entry in
                            Button {
                                appStore.reopenListing(entry)
                            } label: {
                                HistoryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeletion = entry
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
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.brand.background)
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

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                BrandWordmark()
                Text("Snap · Pick · Sell".localized)
                    .brandFont(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
            }

            Spacer(minLength: Spacing.md)

            Button {
                if appStore.session == nil {
                    appStore.isShowingAuth = true
                } else {
                    appStore.signOut()
                }
            } label: {
                Text((appStore.session == nil ? "Sign in" : "Sign out").localized)
                    .brandFont(.caption)
                    .foregroundStyle(Color.brand.foreground)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 44)
                    .background(Color.brand.secondary, in: Capsule())
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel((appStore.session == nil ? "Sign in" : "Sign out").localized)

            IconCircleButton(systemImage: "gearshape.fill", accessibilityLabel: "Settings") {
                appStore.isShowingSettings = true
            }
            .frame(width: 44, height: 44)
        }
        .frame(minHeight: 56)
    }

    private func historyAccessibilityLabel(_ entry: HistoryEntry) -> String {
        HistoryAccessibilityText.rowLabel(for: entry, relativeDate: relativeDate(entry.createdAt))
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
        appStore.deleteHistory(pendingDeletion)
        self.pendingDeletion = nil
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        Text("Your past listings will show up here.".localized)
            .brandFont(.caption)
            .foregroundStyle(Color.brand.mutedForeground)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.horizontal, Spacing.lg)
            .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }
}

private func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
