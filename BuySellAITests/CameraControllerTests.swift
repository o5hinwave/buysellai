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
}
