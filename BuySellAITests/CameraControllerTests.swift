import UIKit
import XCTest
@testable import BuySellAI

final class CameraControllerTests: XCTestCase {
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

    func testCaptureFreezesPreviewBeforeJPEGDownscaleCompletes() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Camera/CameraController.swift"), encoding: .utf8)
        let successRange = try XCTUnwrap(source.range(of: "case .success(let data):"))
        let searchRange = successRange.lowerBound..<source.endIndex
        let stopRange = try XCTUnwrap(source.range(of: "self?.stop()", range: searchRange))
        let downscaleRange = try XCTUnwrap(source.range(of: "ImageTools.jpegDataDownscaled", range: searchRange))

        XCTAssertLessThan(stopRange.lowerBound, downscaleRange.lowerBound)
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
