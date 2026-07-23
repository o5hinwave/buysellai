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
            List {
                Section {
                    authHeader
                }

                providerActions
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, authBottomContentInset, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Sign in".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    closeAuthButton
                }
            }
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

    private var authHeader: some View {
        VStack(spacing: Spacing.sm) {
            BrandWordmark(includeAI: true, showsPeriod: false, size: .large)
            Text("Sign in to sync your listings across devices.".localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(4)
    }

    private var providerActions: some View {
        Section {
            Button {
                signInWithApple()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Label("Continue with Apple".localized, systemImage: "apple.logo")
                    Spacer(minLength: Spacing.sm)
                    if appleSignInTask != nil {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: 44)
            }
            .disabled(store.isSigningIn)
            .accessibilityLabel("Continue with Apple".localized)
            .accessibilitySortPriority(3)

            NavigationLink(value: AuthRoute.email) {
                Label("Continue with Email".localized, systemImage: "envelope.fill")
                    .frame(minHeight: 44)
            }
            .disabled(store.isSigningIn)
            .accessibilityLabel("Continue with Email".localized)
            .accessibilitySortPriority(2)
        }
    }

    private var guestBottomAction: some View {
        Button {
            Haptics.impact(.light)
            dismiss()
        } label: {
            Text("Keep going without an account".localized)
                .frame(maxWidth: .infinity, minHeight: guestActionMinHeight)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Color.brand.primary)
        .disabled(store.isSigningIn)
        .accessibilityLabel("Keep going without an account".localized)
        .accessibilitySortPriority(1)
        .frame(maxWidth: authContentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .background(.bar)
    }

    private var closeAuthButton: some View {
        Button {
            Haptics.impact(.light)
            dismiss()
        } label: {
            Label("Close".localized, systemImage: "xmark")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Close".localized)
    }

    private func signInWithApple() {
        guard appleSignInTask == nil else { return }
        Haptics.impact(.light)
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

    private var authContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 560 : .infinity
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

        List {
            Section {
                TextField("Email".localized, text: $store.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .accessibilityLabel("Email".localized)
                    .accessibilitySortPriority(3)
                    .disabled(store.isSigningIn)

                SecureField("Password".localized, text: $store.password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { signIn(store) }
                    .accessibilityLabel("Password".localized)
                    .accessibilitySortPriority(2)
                    .disabled(store.isSigningIn)
            } footer: {
                Text("Sign in to sync your listings across devices.".localized)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, bottomContentInset, for: .scrollContent)
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
        Button {
            signIn(store)
        } label: {
            Label("Sign in".localized, systemImage: "arrow.right")
                .frame(maxWidth: .infinity, minHeight: signInActionMinHeight)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.brand.primary)
        .disabled(store.canSubmitEmail == false)
        .accessibilityLabel("Sign in".localized)
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
        dynamicTypeSize.isAccessibilitySize ? 120 : 96
    }

    private var signInActionMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 60 : 52
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    private enum Field {
        case email
        case password
    }
}
