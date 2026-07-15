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

    func testCameraConfigurationUnlocksOnlyAfterSuccessfulLock() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)

        XCTAssertEqual(source.components(separatedBy: "defer { device.unlockForConfiguration() }").count - 1, 2)
        XCTAssertNil(source.range(of: #"catch\s*\{\s*device\.unlockForConfiguration\(\)\s*\}"#, options: .regularExpression))
    }

    func testCameraConfigurationCommitIsScopedToAllThrowingSetupPaths() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)
        let configureStart = try XCTUnwrap(source.range(of: "private func configureIfNeeded() throws {"))
        let selectionStart = try XCTUnwrap(source.range(of: "private static func preferredBackCamera()"))
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
        let stopRange = try XCTUnwrap(source.range(of: "self?.stop()", range: searchRange))
        let downscaleRange = try XCTUnwrap(source.range(of: "ImageTools.jpegDataDownscaled", range: searchRange))

        XCTAssertLessThan(stopRange.lowerBound, downscaleRange.lowerBound)
    }

    func testCameraSelectionUsesBackCameraOnlyFallbackChain() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "private static func preferredBackCamera()"))
        XCTAssertNotNil(source.range(of: "AVCaptureDevice.default(deviceType, for: .video, position: .back)"))
        XCTAssertNotNil(source.range(of: "AVCaptureDevice.DiscoverySession("))
        XCTAssertNotNil(source.range(of: "position: .back"))
        XCTAssertNil(source.range(of: "AVCaptureDevice.default(for: .video)"))
        XCTAssertNil(source.range(of: "position: .front"))
        XCTAssertNil(source.range(of: "position: .unspecified"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
