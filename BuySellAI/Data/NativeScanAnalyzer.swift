import Foundation
import ImageIO
import UIKit
import Vision

enum NativeScanAnalyzer {
    static func evidence(from imageData: Data) async -> NativeScanEvidence? {
        guard imageData.isEmpty == false else { return nil }

        let task = Task.detached(priority: .utility) { () -> NativeScanEvidence? in
            guard let image = UIImage(data: imageData),
                  let cgImage = image.cgImage
            else { return nil }

            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = false
            textRequest.minimumTextHeight = 0.02

            let barcodeRequest = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            do {
                try handler.perform([textRequest, barcodeRequest])
            } catch {
                return nil
            }

            let textLines = (textRequest.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            let photoQuality = photoQualityAssessment(from: image)
            let barcodeResults: [VNBarcodeObservation] = barcodeRequest.results ?? []
            let barcodes = barcodeResults.compactMap { observation -> NativeScanBarcode? in
                guard let payload = observation.payloadStringValue else { return nil }
                return NativeScanBarcode(
                    payload: payload,
                    symbology: observation.symbology.rawValue
                )
            }

            return NativeScanEvidence(
                recognizedText: textLines,
                barcodes: barcodes,
                modelOrSerialCandidates: NativeScanEvidence.modelOrSerialCandidates(from: textLines),
                photoQuality: photoQuality
            ).sanitizedForPayload
        }
        return await task.value
    }
}

private func photoQualityAssessment(from image: UIImage) -> PhotoQualityAssessment? {
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }

    let sampleSize = CGSize(width: 32, height: 32)
    let bytesPerPixel = 4
    let bytesPerRow = Int(sampleSize.width) * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: Int(sampleSize.height) * bytesPerRow)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixels,
        width: Int(sampleSize.width),
        height: Int(sampleSize.height),
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.interpolationQuality = .low
    context.draw(cgImage, in: CGRect(origin: .zero, size: sampleSize))

    var luminanceValues: [Double] = []
    luminanceValues.reserveCapacity(Int(sampleSize.width * sampleSize.height))
    var glareCount = 0

    for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
        let red = Double(pixels[index]) / 255
        let green = Double(pixels[index + 1]) / 255
        let blue = Double(pixels[index + 2]) / 255
        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        luminanceValues.append(luminance)
        if red > 0.94, green > 0.94, blue > 0.94 {
            glareCount += 1
        }
    }

    guard luminanceValues.isEmpty == false else { return nil }
    let brightness = luminanceValues.reduce(0, +) / Double(luminanceValues.count)
    let variance = luminanceValues.reduce(0) { total, luminance in
        total + pow(luminance - brightness, 2)
    } / Double(luminanceValues.count)
    let contrast = min(max(sqrt(variance) * 2, 0), 1)
    let glareRatio = Double(glareCount) / Double(luminanceValues.count)
    let shortestSide = min(width, height)
    let issue: PhotoQualityIssue?
    if shortestSide < 360 {
        issue = .tooSmall
    } else if brightness < 0.2 {
        issue = .tooDark
    } else if glareRatio > 0.22 {
        issue = .glare
    } else if contrast < 0.08 {
        issue = .lowContrast
    } else {
        issue = nil
    }

    return PhotoQualityAssessment(
        brightness: brightness,
        contrast: contrast,
        glareRatio: glareRatio,
        width: width,
        height: height,
        issue: issue
    ).sanitizedForPayload
}

private extension CGImagePropertyOrientation {
    init(_ imageOrientation: UIImage.Orientation) {
        switch imageOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
