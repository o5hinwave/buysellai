import UIKit
import XCTest
@testable import BuySellAI

final class ImageToolsTests: XCTestCase {
    func testJPEGDownscaleCapsDecodedPixelLongEdge() throws {
        let image = try makeImage(width: 2400, height: 1200)

        let data = try XCTUnwrap(ImageTools.jpegDataDownscaled(from: image, maxLongEdge: 1600, compression: 0.85))
        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)

        XCTAssertEqual(max(decoded.width, decoded.height), 1600)
        XCTAssertEqual(min(decoded.width, decoded.height), 800)
    }

    func testThumbnailDownscaleUsesRequestedPixelLongEdge() throws {
        let image = try makeImage(width: 640, height: 480)

        let data = try XCTUnwrap(ImageTools.jpegDataDownscaled(from: image, maxLongEdge: 200, compression: 0.75))
        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)

        XCTAssertEqual(max(decoded.width, decoded.height), 200)
        XCTAssertEqual(min(decoded.width, decoded.height), 150)
    }

    func testJPEGDownscaleDoesNotUpscaleSmallImages() throws {
        let image = try makeImage(width: 120, height: 90)

        let data = try XCTUnwrap(ImageTools.jpegDataDownscaled(from: image, maxLongEdge: 200, compression: 0.75))
        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)

        XCTAssertEqual(decoded.width, 120)
        XCTAssertEqual(decoded.height, 90)
    }

    func testJPEGDownscaleKeepsInvalidImageDataUnchanged() {
        let invalid = Data([0x00, 0x01, 0x02])

        XCTAssertEqual(ImageTools.jpegDataDownscaled(from: invalid, maxLongEdge: 200), invalid)
    }

    func testSampleJPEGUsesFixturePixelSize() throws {
        let decoded = try XCTUnwrap(UIImage(data: ImageTools.sampleJPEG())?.cgImage)

        XCTAssertEqual(decoded.width, 640)
        XCTAssertEqual(decoded.height, 480)
    }

    private func makeImage(width: CGFloat, height: CGFloat) throws -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: width * 0.25, y: height * 0.2, width: width * 0.5, height: height * 0.5))
        }
        return image
    }
}
