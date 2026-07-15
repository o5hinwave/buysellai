import SwiftUI

struct AuthView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @State private var store = AuthStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Spacer(minLength: Spacing.xl)

                    VStack(spacing: Spacing.sm) {
                        BrandWordmark(includeAI: true, size: .display)
                        Text("Sign in to sync your listings across devices.".localized)
                            .brandFont(.body)
                            .foregroundStyle(Color.brand.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilitySortPriority(4)

                    VStack(spacing: Spacing.sm) {
                        PrimaryPillButton(title: "Continue with Apple", systemImage: "apple.logo") {
                            Task {
                                do {
                                    let session = try await store.signInWithApple()
                                    await appStore.setSession(session)
                                    dismiss()
                                } catch {
                                    appStore.showToast(error.localizedDescription, style: .error)
                                }
                            }
                        }
                        .accessibilitySortPriority(3)

                        SecondaryPillButton(title: "Continue with Email", systemImage: "envelope.fill") {
                            store.showsEmailForm.toggle()
                        }
                        .accessibilitySortPriority(2)

                        if store.showsEmailForm {
                            VStack(spacing: Spacing.sm) {
                                TextField("Email".localized, text: Binding(
                                    get: { store.email },
                                    set: { store.email = $0 }
                                ))
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .brandFont(.body)
                                    .padding(Spacing.md)
                                    .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                                    .accessibilityLabel("Email".localized)

                                SecureField("Password".localized, text: Binding(
                                    get: { store.password },
                                    set: { store.password = $0 }
                                ))
                                    .textContentType(.password)
                                    .brandFont(.body)
                                    .padding(Spacing.md)
                                    .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                                    .accessibilityLabel("Password".localized)

                                SecondaryPillButton(title: "Sign in", systemImage: "arrow.right") {
                                    Task {
                                        do {
                                            let session = try await store.signInWithEmail()
                                            await appStore.setSession(session)
                                            dismiss()
                                        } catch {
                                            appStore.showToast(error.localizedDescription, style: .error)
                                        }
                                    }
                                }
                            }
                            .accessibilitySortPriority(1.5)
                        }

                        Button("Keep going without an account".localized) {
                            dismiss()
                        }
                        .brandFont(.button)
                        .foregroundStyle(Color.brand.foreground)
                        .frame(minHeight: 52)
                        .accessibilityLabel("Keep going without an account".localized)
                        .accessibilitySortPriority(1)
                    }
                }
                .padding(Spacing.xl)
            }
            .background(Color.brand.background)
        }
    }
}
