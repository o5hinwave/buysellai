import SwiftUI

struct CameraView: View {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appReduceMotion) private var appReduceMotion
    @State private var controller = CameraController()
    @State private var state: CameraStartResult?
    @State private var flashOn = false
    @State private var isCapturing = false
    @State private var bracketOpacity = 0.6

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
        .task {
            state = await controller.start()
        }
    }

    private var cameraOverlay: some View {
        GeometryReader { proxy in
            ZStack {
                CameraCornerBrackets()
                    .stroke(Color.brand.primaryForeground, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: min(proxy.size.width - 64, 320), height: min((proxy.size.width - 64) * 4 / 3, proxy.size.height * 0.56))
                    .opacity(reduceMotion || appReduceMotion ? 0.82 : bracketOpacity)
                    .task {
                        guard reduceMotion == false, appReduceMotion == false else { return }
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            bracketOpacity = 1
                        }
                    }

                VStack {
                    HStack {
                        IconCircleButton(systemImage: "xmark", accessibilityLabel: "Close camera", size: 40, material: true) {
                            controller.stop()
                            onCancel()
                        }

                        Spacer()

                        IconCircleButton(
                            systemImage: flashOn ? "bolt.fill" : "bolt.slash",
                            accessibilityLabel: flashOn ? "Turn flash off" : "Turn flash on",
                            size: 40,
                            material: true
                        ) {
                            flashOn.toggle()
                            controller.setTorch(enabled: flashOn)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, proxy.safeAreaInsets.top + Spacing.md)

                    Spacer()

                    VStack(spacing: Spacing.sm) {
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
                        .accessibilityLabel("Take photo")
                        .accessibilityHint("Captures the current view")

                        Text("Fit the whole item in the frame")
                            .brandFont(.caption)
                            .foregroundStyle(Color.brand.primaryForeground)
                            .shadow(color: Color.brand.cameraBackdrop.opacity(0.5), radius: 4, y: 2)
                    }
                    .padding(.bottom, proxy.safeAreaInsets.bottom + Spacing.xxl)
                }

                if isCapturing {
                    Color.brand.cameraBackdrop.opacity(0.24).ignoresSafeArea()
                    ProgressView()
                        .tint(Color.brand.primaryForeground)
                        .scaleEffect(1.2)
                        .accessibilityLabel("Capturing photo")
                }
            }
        }
    }

    private var starting: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(Color.brand.primaryForeground)
            Text("Starting camera…")
                .brandFont(.body)
                .foregroundStyle(Color.brand.primaryForeground)
        }
        .accessibilityElement(children: .combine)
    }

    private var permissionDenied: some View {
        VStack(spacing: Spacing.lg) {
            Text("Camera access needed to snap items.")
                .brandFont(.title)
                .foregroundStyle(Color.brand.foreground)
                .multilineTextAlignment(.center)

            PrimaryPillButton(title: "Open Settings", systemImage: "gearshape.fill", fillsWidth: false) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }

            SecondaryPillButton(title: "Close", fillsWidth: false) {
                controller.stop()
                onCancel()
            }
        }
        .padding(Spacing.xl)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .padding(Spacing.xl)
    }

    private var cameraFailed: some View {
        VStack(spacing: Spacing.lg) {
            Text("Camera couldn't start.")
                .brandFont(.title)
                .foregroundStyle(Color.brand.foreground)
            SecondaryPillButton(title: "Close", fillsWidth: false) {
                controller.stop()
                onCancel()
            }
        }
        .padding(Spacing.xl)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .padding(Spacing.xl)
    }

    private func capture() {
        guard !isCapturing else { return }
        Haptics.impact(.medium)
        isCapturing = true
        Task {
            do {
                let data = try await controller.capturePhoto(flashOn: flashOn)
                controller.stop()
                await MainActor.run {
                    isCapturing = false
                    onCapture(data)
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                }
            }
        }
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
