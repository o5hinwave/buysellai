import SwiftUI
import UIKit

struct AuthView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var store = AuthStore()
    @State private var path: [AuthRoute] = []
    @State private var appleSignInTask: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: authContentSpacing) {
                    Spacer(minLength: authTopInset)

                    VStack(spacing: Spacing.sm) {
                        BrandWordmark(includeAI: true, showsPeriod: false, size: .display)
                        Text("Sign in to sync your listings across devices.".localized)
                            .brandFont(.body)
                            .foregroundStyle(Color.brand.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilitySortPriority(4)

                    providerActions
                }
                .padding(Spacing.xl)
                .padding(.bottom, authBottomContentInset)
                .frame(maxWidth: authContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                guestBottomAction
            }
            .background(Color.clear)
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
        .onDisappear {
            appleSignInTask?.cancel()
            appleSignInTask = nil
        }
    }

    private var providerActions: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryPillButton(title: "Continue with Apple", systemImage: "apple.logo") {
                guard appleSignInTask == nil else { return }
                appleSignInTask = Task { @MainActor in
                    do {
                        let session = try await store.signInWithApple()
                        guard Task.isCancelled == false else { return }
                        appleSignInTask = nil
                        await appStore.setSession(session)
                        guard Task.isCancelled == false else { return }
                        dismiss()
                    } catch {
                        guard Task.isCancelled == false else { return }
                        appleSignInTask = nil
                        if let message = AuthErrorPresentation.message(for: error) {
                            appStore.showToast(message, style: .error)
                        }
                    }
                }
            }
            .disabled(store.isSigningIn)
            .accessibilitySortPriority(3)

            SecondaryPillButton(title: "Continue with Email", systemImage: "envelope.fill", minHeight: 56) {
                path.append(.email)
            }
            .disabled(store.isSigningIn)
            .accessibilitySortPriority(2)
        }
        .frame(maxWidth: authContentMaxWidth)
        .nativeLiquidGlassControlGroup(spacing: Spacing.sm)
    }

    private var guestBottomAction: some View {
        TextActionButton(title: "Keep going without an account", minHeight: guestActionMinHeight) {
            dismiss()
        }
        .disabled(store.isSigningIn)
        .accessibilitySortPriority(1)
        .frame(maxWidth: authContentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .nativeLiquidGlassControlGroup(spacing: Spacing.md)
        .nativeMaterialBar(tintOpacity: 0.78)
    }

    private var authContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 560 : .infinity
    }

    private var authContentSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Spacing.lg : Spacing.xl
    }

    private var authTopInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Spacing.md : Spacing.xl
    }

    private var authBottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 120 : 96
    }

    private var guestActionMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 60 : 52
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }
}

private enum AuthRoute: Hashable {
    case email
}

private struct EmailSignInView: View {
    let store: AuthStore
    let onSignIn: (AuthSession) async -> Void
    let onError: (String) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var emailSignInTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(spacing: Spacing.sm) {
                TextField("Email".localized, text: $store.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .brandFont(.body)
                    .focused($focusedField, equals: .email)
                    .focusedInputChrome(isFocused: focusedField == .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .accessibilityLabel("Email".localized)
                    .accessibilitySortPriority(3)
                    .disabled(store.isSigningIn)

                SecureField("Password".localized, text: $store.password)
                    .textContentType(.password)
                    .brandFont(.body)
                    .focused($focusedField, equals: .password)
                    .focusedInputChrome(isFocused: focusedField == .password)
                    .submitLabel(.go)
                    .onSubmit { signIn(store) }
                    .accessibilityLabel("Password".localized)
                    .accessibilitySortPriority(2)
                    .disabled(store.isSigningIn)
            }
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            .padding(.bottom, bottomContentInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            emailBottomAction(store)
        }
        .background(Color.clear)
        .navigationTitle("Email".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            focusedField = .email
        }
        .onDisappear {
            emailSignInTask?.cancel()
            emailSignInTask = nil
        }
    }

    private func signIn(_ store: AuthStore) {
        guard store.canSubmitEmail else { return }
        guard emailSignInTask == nil else { return }
        emailSignInTask = Task { @MainActor in
            do {
                let session = try await store.signInWithEmail()
                guard Task.isCancelled == false else { return }
                emailSignInTask = nil
                await onSignIn(session)
            } catch {
                guard Task.isCancelled == false else { return }
                emailSignInTask = nil
                if let message = AuthErrorPresentation.message(for: error) {
                    onError(message)
                }
            }
        }
    }

    private func emailBottomAction(_ store: AuthStore) -> some View {
        PrimaryPillButton(title: "Sign in", systemImage: "arrow.right", maxFillWidth: contentMaxWidth) {
            signIn(store)
        }
        .disabled(store.canSubmitEmail == false)
        .accessibilitySortPriority(1)
        .frame(maxWidth: contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .nativeLiquidGlassControlGroup(spacing: Spacing.md)
        .nativeMaterialBar(tintOpacity: 0.78)
    }

    private var contentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 560 : .infinity
    }

    private var bottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 120 : 96
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    private enum Field {
        case email
        case password
    }
}
