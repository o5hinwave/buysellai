import UIKit
import XCTest
@testable import BuySellAI

final class CameraControllerTests: XCTestCase {
    func testCameraViewfinderUsesTwentyFourPointHorizontalInsetAndThreeByFourGuide() {
        let size = CameraViewfinderLayout.size(in: CGSize(width: 390, height: 844))

        XCTAssertEqual(CameraViewfinderLayout.horizontalInset, 24)
        XCTAssertEqual(size.width, 342, accuracy: 0.001)
        XCTAssertEqual(size.height, 456, accuracy: 0.001)
        XCTAssertEqual(size.height / size.width, CameraViewfinderLayout.aspectRatio, accuracy: 0.001)
    }

    func testCameraViewfinderPreservesAspectRatioWhenHeightConstrained() {
        let size = CameraViewfinderLayout.size(in: CGSize(width: 390, height: 520))

        XCTAssertEqual(size.height, 291.2, accuracy: 0.001)
        XCTAssertEqual(size.width, 218.4, accuracy: 0.001)
        XCTAssertEqual(size.height / size.width, CameraViewfinderLayout.aspectRatio, accuracy: 0.001)
    }

    func testTorchToggleRequiresBackCameraTorchAvailability() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "func isTorchAvailable() async -> Bool"))
        XCTAssertNotNil(source.range(of: "func setTorch(enabled: Bool) async -> Bool"))
        XCTAssertNotNil(source.range(of: "private static func supportsTorch(_ device: AVCaptureDevice) -> Bool"))
        XCTAssertNotNil(source.range(of: "device.position == .back && device.hasTorch && device.isTorchAvailable"))
        XCTAssertNotNil(source.range(of: "continuation.resume(returning: false)"))
    }

    func testPhotoFlashOnlyTurnsOnWhenSelectedBackCameraSupportsFlash() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "private static func supportsFlash(_ device: AVCaptureDevice) -> Bool"))
        XCTAssertNotNil(source.range(of: "device.position == .back && device.hasFlash"))
        XCTAssertNotNil(source.range(of: "let supportsFlash = self.videoDevice.map(Self.supportsFlash) ?? false"))
        XCTAssertNotNil(source.range(of: "if supportsFlash, self.photoOutput.supportedFlashModes.contains(.on)"))
        XCTAssertNotNil(source.range(of: "settings.flashMode = flashOn ? .on : .off"))
    }

    func testCaptureRejectsUnstartedSessionBeforeTouchingPhotoOutput() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)
        let captureStart = try XCTUnwrap(source.range(of: "func capturePhoto(flashOn: Bool) async throws -> Data {"))
        let captureEnd = try XCTUnwrap(source.range(of: "private func stopRunningSynchronously()"))
        let captureSource = String(source[captureStart.lowerBound..<captureEnd.lowerBound])

        let guardRange = try XCTUnwrap(captureSource.range(of: "guard self.configured, self.session.isRunning else"))
        let failureRange = try XCTUnwrap(captureSource.range(
            of: "continuation.resume(throwing: CameraError.captureFailed)",
            range: guardRange.lowerBound..<captureSource.endIndex
        ))
        let settingsRange = try XCTUnwrap(captureSource.range(of: "let settings = AVCapturePhotoSettings()"))
        let captureCallRange = try XCTUnwrap(captureSource.range(of: "self.photoOutput.capturePhoto(with: settings, delegate: delegate)"))

        XCTAssertLessThan(guardRange.lowerBound, settingsRange.lowerBound)
        XCTAssertLessThan(failureRange.lowerBound, settingsRange.lowerBound)
        XCTAssertLessThan(settingsRange.lowerBound, captureCallRange.lowerBound)
    }

    func testCaptureVideoRotationAngleMatchesDeviceOrientation() {
        XCTAssertEqual(CameraVideoRotation.angle(for: .portrait), 90)
        XCTAssertEqual(CameraVideoRotation.angle(for: .landscapeLeft), 0)
        XCTAssertEqual(CameraVideoRotation.angle(for: .landscapeRight), 180)
        XCTAssertEqual(CameraVideoRotation.angle(for: .portraitUpsideDown), 270)
    }

    func testCaptureVideoRotationAngleFallsBackToPortraitForUnknownFlatOrientations() {
        XCTAssertEqual(CameraVideoRotation.angle(for: .unknown), 90)
        XCTAssertEqual(CameraVideoRotation.angle(for: .faceUp), 90)
        XCTAssertEqual(CameraVideoRotation.angle(for: .faceDown), 90)
    }

    func testCameraPreviewUpdatesRotationFromWindowSceneOrientation() throws {
        XCTAssertEqual(CameraPreviewRotation.angle(for: .portrait), 90)
        XCTAssertEqual(CameraPreviewRotation.angle(for: .landscapeLeft), 0)
        XCTAssertEqual(CameraPreviewRotation.angle(for: .landscapeRight), 180)
        XCTAssertEqual(CameraPreviewRotation.angle(for: .portraitUpsideDown), 270)
        XCTAssertEqual(CameraPreviewRotation.angle(for: .unknown), 90)

        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraPreview.swift"), encoding: .utf8)
        XCTAssertNotNil(source.range(of: "override func layoutSubviews()"))
        XCTAssertNotNil(source.range(of: "videoPreviewLayer.frame = bounds"))
        XCTAssertNotNil(source.range(of: "func updateVideoRotation()"))
        XCTAssertNotNil(source.range(of: "window?.windowScene?.interfaceOrientation ?? .portrait"))
        XCTAssertNotNil(source.range(of: "connection.videoRotationAngle = angle"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "view.updateVideoRotation()").count - 1, 1)
        XCTAssertNotNil(source.range(of: "uiView.updateVideoRotation()"))
    }

    func testCameraPreviewConvertsTapToDeviceFocusPoint() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraPreview.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "var onTapToFocus: (CameraFocusTap) -> Void = { _ in }"))
        XCTAssertNotNil(source.range(of: "struct CameraFocusTap: Equatable"))
        XCTAssertNotNil(source.range(of: "let viewPoint: CGPoint"))
        XCTAssertNotNil(source.range(of: "let devicePoint: CGPoint"))
        XCTAssertNotNil(source.range(of: "UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))"))
        XCTAssertNotNil(source.range(of: "recognizer.cancelsTouchesInView = false"))
        XCTAssertNotNil(source.range(of: "videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint)"))
        XCTAssertNotNil(source.range(of: "onTapToFocus?(CameraFocusTap(viewPoint: viewPoint, devicePoint: devicePoint))"))
    }

    func testCameraConfigurationUnlocksOnlyAfterSuccessfulLock() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)

        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "defer { device.unlockForConfiguration() }").count - 1, 3)
        XCTAssertNil(source.range(of: #"catch\s*\{\s*device\.unlockForConfiguration\(\)\s*\}"#, options: .regularExpression))
    }

    func testCameraConfigurationLogsFocusExposureFallbackWithoutEmptyCatch() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)
        let configureStart = try XCTUnwrap(source.range(of: "private func configureFocusAndExposure(for device: AVCaptureDevice)"))
        let selectionStart = try XCTUnwrap(source.range(of: "private func currentCapabilities()"))
        let configureSource = String(source[configureStart.lowerBound..<selectionStart.lowerBound])

        XCTAssertNotNil(source.range(of: #"import os"#))
        XCTAssertNotNil(source.range(of: #"Logger(subsystem: "BuySellAI", category: "Camera")"#))
        XCTAssertNotNil(configureSource.range(of: #"logger.warning("Camera focus and exposure configuration skipped")"#))
        XCTAssertNil(configureSource.range(of: #"catch\s*\{\s*\}"#, options: .regularExpression))
    }

    func testCameraConfigurationCommitIsScopedToAllThrowingSetupPaths() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)
        let configureStart = try XCTUnwrap(source.range(of: "private func configureIfNeeded() throws {"))
        let selectionStart = try XCTUnwrap(source.range(of: "private func configureFocusAndExposure(for device: AVCaptureDevice)"))
        let configureSource = String(source[configureStart.lowerBound..<selectionStart.lowerBound])

        XCTAssertEqual(configureSource.components(separatedBy: "session.commitConfiguration()").count - 1, 1)

        let beginRange = try XCTUnwrap(configureSource.range(of: "session.beginConfiguration()"))
        let commitRange = try XCTUnwrap(configureSource.range(of: "defer { session.commitConfiguration() }"))
        let inputRange = try XCTUnwrap(configureSource.range(of: "let input = try AVCaptureDeviceInput(device: device)"))
        let addInputRange = try XCTUnwrap(configureSource.range(of: "session.addInput(input)"))

        XCTAssertLessThan(beginRange.lowerBound, commitRange.lowerBound)
        XCTAssertLessThan(commitRange.lowerBound, inputRange.lowerBound)
        XCTAssertLessThan(inputRange.lowerBound, addInputRange.lowerBound)
    }

    func testCaptureFreezesPreviewBeforeJPEGDownscaleCompletes() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)
        let successRange = try XCTUnwrap(source.range(of: "case .success(let data):"))
        let searchRange = successRange.lowerBound..<source.endIndex
        let stopRange = try XCTUnwrap(source.range(of: "self?.stopRunningSynchronously()", range: searchRange))
        let downscaleRange = try XCTUnwrap(source.range(of: "ImageTools.jpegDataDownscaled", range: searchRange))

        XCTAssertLessThan(stopRange.lowerBound, downscaleRange.lowerBound)
    }

    func testCaptureRejectsMalformedPhotoDataBeforeContinuingFlow() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)
        let successRange = try XCTUnwrap(source.range(of: "case .success(let data):"))
        let searchRange = successRange.lowerBound..<source.endIndex

        XCTAssertNotNil(source.range(of: "guard let downscaled = ImageTools.jpegDataDownscaled", range: searchRange))
        XCTAssertNotNil(source.range(of: "continuation.resume(throwing: CameraError.captureFailed)", range: searchRange))
        XCTAssertNotNil(source.range(of: "continuation.resume(returning: downscaled)", range: searchRange))
    }

    func testCameraCloseCancelsInFlightCaptureBeforeContinuingFlow() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"@State private var captureTask: Task<Void, Never>?"#))
        XCTAssertNotNil(source.range(of: #"@State private var photoImportTask: Task<Void, Never>?"#))
        XCTAssertNotNil(source.range(of: #"@State private var flashTask: Task<Void, Never>?"#))
        XCTAssertNotNil(source.range(of: #"@State private var cameraSwitchTask: Task<Void, Never>?"#))
        XCTAssertNotNil(source.range(of: #"@State private var focusTask: Task<Void, Never>?"#))
        XCTAssertNotNil(source.range(of: "private func cancelInFlightCapture()"))
        XCTAssertNotNil(source.range(of: "captureTask?.cancel()"))
        XCTAssertNotNil(source.range(of: "photoImportTask?.cancel()"))
        XCTAssertNotNil(source.range(of: "flashTask?.cancel()"))
        XCTAssertNotNil(source.range(of: "cameraSwitchTask?.cancel()"))
        XCTAssertNotNil(source.range(of: "focusTask?.cancel()"))

        let closeRange = try XCTUnwrap(source.range(of: #"accessibilityLabel: "Close camera""#))
        let closeSearchRange = closeRange.lowerBound..<source.endIndex
        let cancelRange = try XCTUnwrap(source.range(of: "cancelInFlightCapture()", range: closeSearchRange))
        let onCancelRange = try XCTUnwrap(source.range(of: "onCancel()", range: closeSearchRange))
        XCTAssertLessThan(cancelRange.lowerBound, onCancelRange.lowerBound)

        XCTAssertNotNil(source.range(of: ".onDisappear {"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "captureTask = Task").count - 1, 2)
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "guard Task.isCancelled == false else { return }").count - 1, 3)
    }

    func testCameraPhotoImportUsesPhotosPickerAndNormalizesToJPEGBeforeFlow() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "import PhotosUI"))
        XCTAssertNotNil(source.range(of: "@State private var selectedPhotoItem: PhotosPickerItem?"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())").count - 1, 2)
        XCTAssertNotNil(source.range(of: #".onChange(of: selectedPhotoItem) { _, item in"#))
        XCTAssertNotNil(source.range(of: "importPhoto(item)"))
        XCTAssertNotNil(source.range(of: "private func importPhoto(_ item: PhotosPickerItem?)"))
        XCTAssertNotNil(source.range(of: "try await item.loadTransferable(type: Data.self)"))
        XCTAssertNotNil(source.range(of: "ImageTools.jpegDataDownscaled(from: data, maxLongEdge: 1600, compression: 0.85)"))
        let importStart = try XCTUnwrap(source.range(of: "private func importPhoto(_ item: PhotosPickerItem?)"))
        let cancelStart = try XCTUnwrap(source.range(of: "private func cancelInFlightCapture()"))
        let importSource = String(source[importStart.lowerBound..<cancelStart.lowerBound])

        XCTAssertNotNil(importSource.range(of: "controller.stop()"))
        XCTAssertNotNil(importSource.range(of: "onCapture(downscaled)"))
        XCTAssertNotNil(source.range(of: #"text: "Photo couldn't be imported.".localized"#))
        XCTAssertNil(importSource.range(of: "onCapture(data)", options: .caseInsensitive))
    }

    func testTargetedScanCameraFallbackOffersSkipInsteadOfClose() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"var onSkipTargetedScan: (() -> Void)? = nil"#))
        XCTAssertNotNil(source.range(of: #"private func closeOrSkipFallbackButton(sortPriority: Double) -> some View"#))
        XCTAssertNotNil(source.range(of: #"if scanRequest != nil, let onSkipTargetedScan {"#))
        XCTAssertNotNil(source.range(of: #"onSkipTargetedScan()"#))
        XCTAssertNotNil(source.range(of: #"private var fallbackDismissTitle: String"#))
        XCTAssertNotNil(source.range(of: #"scanRequest == nil ? "Close" : "Skip""#))
        XCTAssertNotNil(source.range(of: #"Keeps going without this scan."#))
        XCTAssertNotNil(source.range(of: #"fallbackPanel {"#))
        XCTAssertNotNil(source.range(of: #"Label("Open Settings".localized, systemImage: "gearshape.fill")"#))
    }

    func testCameraFlashToggleTaskIsOwnedAndCancelled() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "flashTask?.cancel()"))
        XCTAssertNotNil(source.range(of: "flashTask = Task { @MainActor in"))
        XCTAssertNotNil(source.range(of: "let applied = await controller.setTorch(enabled: requestedState)"))
        XCTAssertNotNil(source.range(of: "guard Task.isCancelled == false else { return }"))
        XCTAssertNotNil(source.range(of: "flashTask = nil"))
        XCTAssertNil(source.range(of: "Task {\n            let applied = await controller.setTorch(enabled: requestedState)"))
    }

    func testSynchronousCaptureFreezeUsesCameraQueueWithoutSelfDeadlock() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "private static let queueKey = DispatchSpecificKey<Bool>()"))
        XCTAssertNotNil(source.range(of: "queue.setSpecific(key: Self.queueKey, value: true)"))
        XCTAssertNotNil(source.range(of: "private func stopRunningSynchronously()"))
        XCTAssertNotNil(source.range(of: "DispatchQueue.getSpecific(key: Self.queueKey) == true"))
        XCTAssertNotNil(source.range(of: "queue.sync"))
        XCTAssertNotNil(source.range(of: "private func stopRunningIfNeeded()"))
    }

    func testCameraSelectionStartsOnBackAndOnlySwitchesToExplicitFrontFallbackChain() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "private static func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice?"))
        XCTAssertNotNil(source.range(of: "Self.preferredCamera(position: .back)"))
        XCTAssertNotNil(source.range(of: "AVCaptureDevice.default(deviceType, for: .video, position: position)"))
        XCTAssertNotNil(source.range(of: "AVCaptureDevice.DiscoverySession("))
        XCTAssertNotNil(source.range(of: "position: position"))
        XCTAssertNotNil(source.range(of: "func switchCamera() async -> CameraCapabilities"))
        XCTAssertNotNil(source.range(of: "let nextPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back"))
        XCTAssertNotNil(source.range(of: "Self.hasCamera(position: nextPosition)"))
        XCTAssertNotNil(source.range(of: "CameraCapabilities("))
        XCTAssertNotNil(source.range(of: "canSwitchCamera: Self.hasCamera(position: .back) && Self.hasCamera(position: .front)"))
        XCTAssertNil(source.range(of: "AVCaptureDevice.default(for: .video)"))
        XCTAssertNil(source.range(of: "position: .unspecified"))
    }

    func testTapFocusAndExposureUsesLockedClampedDevicePoint() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "func focusAndExpose(at devicePoint: CGPoint) async -> Bool"))
        XCTAssertNotNil(source.range(of: "let point = Self.clampedDevicePoint(devicePoint)"))
        XCTAssertNotNil(source.range(of: "device.focusPointOfInterest = point"))
        XCTAssertNotNil(source.range(of: "device.exposurePointOfInterest = point"))
        XCTAssertNotNil(source.range(of: "device.focusMode = .autoFocus"))
        XCTAssertNotNil(source.range(of: "device.exposureMode = .continuousAutoExposure"))
        XCTAssertNotNil(source.range(of: #"logger.warning("Camera tap focus and exposure skipped")"#))
        XCTAssertNotNil(source.range(of: "private static func clampedDevicePoint(_ point: CGPoint) -> CGPoint"))
    }

    func testCameraViewOwnsSwitchAndTapFocusTasks() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "CameraPreview(session: controller.session) { tap in"))
        XCTAssertNotNil(source.range(of: "handleFocusTap(tap)"))
        XCTAssertNotNil(source.range(of: "CameraFocusRing()"))
        XCTAssertNotNil(source.range(of: #"systemImage: "arrow.triangle.2.circlepath.camera""#))
        XCTAssertNotNil(source.range(of: "cameraSwitchAccessibilityLabel"))
        XCTAssertNotNil(source.range(of: "let capabilities = await controller.switchCamera()"))
        XCTAssertNotNil(source.range(of: "_ = await controller.setTorch(enabled: false)"))
        XCTAssertNotNil(source.range(of: "focusTask = Task { @MainActor in"))
        XCTAssertNotNil(source.range(of: "_ = await controller.focusAndExpose(at: tap.devicePoint)"))
    }

    func testCameraScenePhasePausesAndRestartsSession() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"@Environment(\.scenePhase) private var scenePhase"#))
        XCTAssertNotNil(source.range(of: #"@State private var didPauseSessionForScenePhase = false"#))
        XCTAssertNotNil(source.range(of: #"@State private var restartTask: Task<Void, Never>?"#))
        XCTAssertNotNil(source.range(of: "private func startCamera() async"))
        XCTAssertNotNil(source.range(of: "guard scenePhase == .active else"))
        XCTAssertNotNil(source.range(of: ".task {\n            await startCamera()\n        }"))
        XCTAssertNotNil(source.range(of: ".onChange(of: scenePhase) { _, newPhase in"))
        XCTAssertNotNil(source.range(of: "private func handleScenePhase(_ phase: ScenePhase)"))
        XCTAssertNotNil(source.range(of: "case .active:"))
        XCTAssertNotNil(source.range(of: "guard didPauseSessionForScenePhase else { return }"))
        XCTAssertNotNil(source.range(of: "restartCameraAfterInterruption()"))
        XCTAssertNotNil(source.range(of: "case .inactive, .background:"))
        XCTAssertNotNil(source.range(of: "pauseCameraForScenePhase()"))
        XCTAssertNotNil(source.range(of: "private func pauseCameraForScenePhase()"))
        XCTAssertNotNil(source.range(of: "controller.stop()"))
        XCTAssertNotNil(source.range(of: "captureTask?.cancel()"))
        XCTAssertNotNil(source.range(of: "private func restartCameraAfterInterruption()"))
        XCTAssertNotNil(source.range(of: "restartTask = Task { @MainActor in"))
        XCTAssertNotNil(source.range(of: "await startCamera()"))
        XCTAssertNotNil(source.range(of: "restartTask?.cancel()"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
