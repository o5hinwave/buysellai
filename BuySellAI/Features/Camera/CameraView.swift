import SwiftUI

struct CameraView: View {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var controller = CameraController()
    @State private var state: CameraStartResult?
    @State private var flashOn = false
    @State private var isFlashAvailable = true
    @State private var isCapturing = false
    @State private var bracketOpacity = 0.6
    @State private var captureErrorToast: ToastMessage?
    @State private var captureTask: Task<Void, Never>?
    @State private var flashTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            switch state {
            case .ready:
                CameraPreview(session: controller.session)
                    .ignoresSafeArea()
                    .overlay(cameraOverlay)
            case .denied:
                Color.brand.cameraBackdrop.ignoresSafeArea()
                permissionDenied
            case .failed:
                Color.brand.cameraBackdrop.ignoresSafeArea()
                cameraFailed
            case nil:
                Color.brand.cameraBackdrop.ignoresSafeArea()
                starting
            }
        }
        .overlay(alignment: .top) {
            if let captureErrorToast {
                ToastView(toast: captureErrorToast)
                    .padding(.top, Spacing.xl)
                    .transition(AppMotion.toastTransition(reduceMotion: shouldReduceMotion))
                    .task(id: captureErrorToast.id) {
                        try? await Task.sleep(nanoseconds: 2_300_000_000)
                        if self.captureErrorToast?.id == captureErrorToast.id {
                            self.captureErrorToast = nil
                        }
                    }
            }
        }
        .task {
            if LaunchArguments.contains(LaunchArguments.uiTestingCameraDenied) {
                state = .denied
                return
            }
            if LaunchArguments.contains(LaunchArguments.uiTestingCameraReady) {
                isFlashAvailable = true
                state = .ready
                return
            }
            let startResult = await controller.start()
            state = startResult
            if case .ready = startResult {
                isFlashAvailable = await controller.isTorchAvailable()
            } else {
                isFlashAvailable = false
            }
        }
        .onDisappear {
            flashTask?.cancel()
            flashTask = nil
            cancelInFlightCapture()
        }
    }

    private var cameraOverlay: some View {
        GeometryReader { proxy in
            let viewfinderSize = CameraViewfinderLayout.size(in: proxy.size)

            ZStack {
                CameraCornerBrackets()
                    .stroke(Color.brand.primaryForeground, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: viewfinderSize.width, height: viewfinderSize.height)
                    .opacity(shouldReduceMotion ? 0.82 : bracketOpacity)
                    .task(id: shouldReduceMotion) {
                        if shouldReduceMotion {
                            bracketOpacity = 0.82
                            return
                        }
                        bracketOpacity = 0.6
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            bracketOpacity = 1
                        }
                    }

                VStack {
                    HStack {
                        IconCircleButton(systemImage: "xmark", accessibilityLabel: "Close camera", size: 40, material: true) {
                            cancelInFlightCapture()
                            onCancel()
                        }

                        Spacer()

                        IconCircleButton(
                            systemImage: isFlashAvailable && flashOn ? "bolt.fill" : "bolt.slash",
                            accessibilityLabel: flashAccessibilityLabel,
                            size: 40,
                            material: true
                        ) {
                            toggleFlash()
                        }
                        .disabled(isFlashAvailable == false)
                        .opacity(isFlashAvailable ? 1 : 0.55)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, proxy.safeAreaInsets.top + Spacing.md)
                    .nativeLiquidGlassControlGroup(spacing: Spacing.md)

                    Spacer()

                    cameraBottomControls(safeAreaBottom: proxy.safeAreaInsets.bottom)
                }

                if isCapturing {
                    Color.brand.cameraBackdrop.opacity(0.24).ignoresSafeArea()
                    ProgressView()
                        .tint(Color.brand.primaryForeground)
                        .scaleEffect(1.2)
                        .accessibilityLabel("Capturing photo".localized)
                }
            }
        }
    }

    @ViewBuilder
    private func cameraBottomControls(safeAreaBottom: CGFloat) -> some View {
        VStack(spacing: Spacing.sm) {
            shutterButton
            cameraHintLabel
        }
        .frame(maxWidth: cameraBottomMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? Spacing.xl : 0)
        .padding(.bottom, safeAreaBottom + cameraBottomPadding)
    }

    private var shutterButton: some View {
        Button {
            capture()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.brand.primaryForeground, lineWidth: 5)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(Color.brand.primaryForeground)
                    .frame(width: 64, height: 64)
            }
        }
        .buttonStyle(PressButtonStyle())
        .disabled(isCapturing)
        .accessibilityLabel("Take photo".localized)
        .accessibilityHint("Captures the current view".localized)
    }

    @ViewBuilder
    private var cameraHintLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text("Fit the whole item in the frame".localized)
                .brandFont(.caption)
                .foregroundStyle(Color.brand.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .nativeMaterialPill(tintOpacity: 0.72, strokeOpacity: 0.64)
        } else {
            Text("Fit the whole item in the frame".localized)
                .brandFont(.caption)
                .foregroundStyle(Color.brand.primaryForeground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .shadow(color: Color.brand.cameraBackdrop.opacity(0.5), radius: 4, y: 2)
        }
    }

    private var cameraBottomPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Spacing.xxxl : Spacing.xxl
    }

    private var cameraBottomMaxWidth: CGFloat {
        usesRegularWidthLayout ? 420 : .infinity
    }

    private var starting: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(Color.brand.primaryForeground)
            Text("Starting camera…".localized)
                .brandFont(.body)
                .foregroundStyle(Color.brand.primaryForeground)
        }
        .accessibilityElement(children: .combine)
    }

    private var permissionDenied: some View {
        fallbackPanel {
            Text("Camera access needed to snap items.".localized)
                .brandFont(.title)
                .foregroundStyle(Color.brand.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .accessibilitySortPriority(3)

            PrimaryPillButton(
                title: "Open Settings",
                systemImage: "gearshape.fill",
                fillsWidth: fallbackActionsFillWidth,
                maxFillWidth: fallbackActionMaxWidth
            ) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .accessibilitySortPriority(2)

            SecondaryPillButton(
                title: "Close",
                fillsWidth: fallbackActionsFillWidth,
                maxFillWidth: fallbackActionMaxWidth
            ) {
                controller.stop()
                onCancel()
            }
            .accessibilitySortPriority(1)
        }
    }

    private var cameraFailed: some View {
        fallbackPanel {
            Text("Camera couldn't start.".localized)
                .brandFont(.title)
                .foregroundStyle(Color.brand.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .accessibilitySortPriority(2)

            SecondaryPillButton(
                title: "Close",
                fillsWidth: fallbackActionsFillWidth,
                maxFillWidth: fallbackActionMaxWidth
            ) {
                controller.stop()
                onCancel()
            }
            .accessibilitySortPriority(1)
        }
    }

    private func fallbackPanel<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    content()
                }
                .frame(maxWidth: fallbackPanelMaxWidth)
                .padding(Spacing.xl)
                .nativeMaterialPanel(cornerRadius: Radius.xl, tintOpacity: 0.78)
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityElement(children: .contain)
        }
    }

    private var fallbackPanelMaxWidth: CGFloat {
        usesRegularWidthLayout ? 420 : .infinity
    }

    private var fallbackActionMaxWidth: CGFloat {
        usesRegularWidthLayout ? 360 : .infinity
    }

    private var fallbackActionsFillWidth: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    private var flashAccessibilityLabel: String {
        guard isFlashAvailable else { return "Flash unavailable" }
        return flashOn ? "Turn flash off" : "Turn flash on"
    }

    private func toggleFlash() {
        guard isFlashAvailable else { return }
        let requestedState = !flashOn
        flashOn = requestedState
        flashTask?.cancel()
        flashTask = Task { @MainActor in
            let applied = await controller.setTorch(enabled: requestedState)
            guard Task.isCancelled == false else { return }
            if applied == false {
                flashOn = false
                isFlashAvailable = false
            }
            flashTask = nil
        }
    }

    private func capture() {
        guard !isCapturing else { return }
        Haptics.impact(.medium)
        if LaunchArguments.contains(LaunchArguments.uiTestingCameraSampleCapture) {
            isCapturing = true
            captureTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 150_000_000)
                    guard Task.isCancelled == false else { return }
                    controller.stop()
                    isCapturing = false
                    captureTask = nil
                    onCapture(ImageTools.sampleJPEG())
                } catch {
                    guard Task.isCancelled == false else { return }
                    isCapturing = false
                    captureTask = nil
                }
            }
            return
        }

        isCapturing = true
        captureTask = Task {
            do {
                let data = try await controller.capturePhoto(flashOn: flashOn)
                guard Task.isCancelled == false else { return }
                controller.stop()
                isCapturing = false
                captureTask = nil
                onCapture(data)
            } catch {
                guard Task.isCancelled == false else { return }
                isCapturing = false
                captureTask = nil
                Haptics.notify(.error)
                captureErrorToast = ToastMessage(
                    text: CameraError.captureFailed.localizedDescription,
                    style: .error
                )
            }
        }
    }

    private func cancelInFlightCapture() {
        captureTask?.cancel()
        captureTask = nil
        isCapturing = false
        controller.stop()
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: reduceMotion, app: appReduceMotion)
    }
}

enum CameraViewfinderLayout {
    static let horizontalInset: CGFloat = 24
    static let aspectRatio: CGFloat = 4.0 / 3.0
    static let maxHeightFraction: CGFloat = 0.56

    static func size(in container: CGSize) -> CGSize {
        let availableWidth = max(0, container.width - horizontalInset * 2)
        let maxHeight = max(0, container.height * maxHeightFraction)
        let idealHeight = availableWidth * aspectRatio

        if idealHeight <= maxHeight {
            return CGSize(width: availableWidth, height: idealHeight)
        }

        return CGSize(width: maxHeight / aspectRatio, height: maxHeight)
    }
}

struct CameraCornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 32
        let inset: CGFloat = 0

        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY + inset))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.minX + inset, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY - inset))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - length))

        return path
    }
}
