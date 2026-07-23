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

    func testJPEGDownscaleRejectsInvalidImageData() {
        let invalid = Data([0x00, 0x01, 0x02])

        XCTAssertNil(ImageTools.jpegDataDownscaled(from: invalid, maxLongEdge: 200))
    }

    func testSampleJPEGUsesFixturePixelSize() throws {
        let decoded = try XCTUnwrap(UIImage(data: ImageTools.sampleJPEG())?.cgImage)

        XCTAssertEqual(decoded.width, 640)
        XCTAssertEqual(decoded.height, 480)
    }

    func testSampleJPEGContainsLampLikeScreenshotFixtureRegions() throws {
        let decoded = try XCTUnwrap(UIImage(data: ImageTools.sampleJPEG())?.cgImage)

        let background = try pixel(in: decoded, x: 48, y: 48)
        let shade = try pixel(in: decoded, x: 320, y: 168)
        let base = try pixel(in: decoded, x: 320, y: 340)
        let table = try pixel(in: decoded, x: 320, y: 410)

        XCTAssertGreaterThan(shade.orangeScore, 55)
        XCTAssertGreaterThan(abs(Int(shade.luminance) - Int(background.luminance)), 20)
        XCTAssertLessThan(base.luminance, shade.luminance)
        XCTAssertGreaterThan(abs(Int(table.luminance) - Int(background.luminance)), 12)
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

    private func pixel(in image: CGImage, x: Int, y: Int) throws -> Pixel {
        let rect = CGRect(x: x, y: y, width: 1, height: 1)
        let cropped = try XCTUnwrap(image.cropping(to: rect))
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Pixel(red: bytes[0], green: bytes[1], blue: bytes[2], alpha: bytes[3])
    }
}

private struct Pixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    var luminance: UInt8 {
        UInt8((Int(red) * 299 + Int(green) * 587 + Int(blue) * 114) / 1_000)
    }

    var orangeScore: Int {
        Int(red) - Int(blue)
    }
}
