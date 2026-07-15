import SwiftUI

struct AuthView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @State private var store = AuthStore()
    @State private var path: [AuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Spacer(minLength: Spacing.xl)

                    VStack(spacing: Spacing.sm) {
                        BrandWordmark(includeAI: true, showsPeriod: false, size: .display)
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

                        SecondaryPillButton(title: "Continue with Email", systemImage: "envelope.fill", minHeight: 56) {
                            path.append(.email)
                        }
                        .accessibilitySortPriority(2)

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
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .email:
                    EmailSignInView(
                        store: store,
                        onSignIn: { session in
                            await appStore.setSession(session)
                            dismiss()
                        },
                        onError: { message in
                            appStore.showToast(message, style: .error)
                        }
                    )
                }
            }
        }
    }
}

private enum AuthRoute: Hashable {
    case email
}

private struct EmailSignInView: View {
    let store: AuthStore
    let onSignIn: (AuthSession) async -> Void
    let onError: (String) -> Void

    @FocusState private var focusedField: Field?

    var body: some View {
        @Bindable var store = store

        VStack(spacing: Spacing.sm) {
            TextField("Email".localized, text: $store.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .brandFont(.body)
                .padding(Spacing.md)
                .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .accessibilityLabel("Email".localized)
                .accessibilitySortPriority(3)

            SecureField("Password".localized, text: $store.password)
                .textContentType(.password)
                .brandFont(.body)
                .padding(Spacing.md)
                .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { signIn(store) }
                .accessibilityLabel("Password".localized)
                .accessibilitySortPriority(2)

            PrimaryPillButton(title: "Sign in", systemImage: "arrow.right") {
                signIn(store)
            }
            .disabled(store.email.isEmpty || store.password.isEmpty || store.isSigningIn)
            .accessibilitySortPriority(1)

            Spacer()
        }
        .padding(Spacing.xl)
        .background(Color.brand.background)
        .navigationTitle("Email".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            focusedField = .email
        }
    }

    private func signIn(_ store: AuthStore) {
        guard store.email.isEmpty == false, store.password.isEmpty == false else { return }
        Task {
            do {
                let session = try await store.signInWithEmail()
                await onSignIn(session)
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    private enum Field {
        case email
        case password
    }
}
