import UIKit

enum ImageTools {
    static func jpegDataDownscaled(from data: Data, maxLongEdge: CGFloat, compression: CGFloat = 0.85) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegDataDownscaled(from: image, maxLongEdge: maxLongEdge, compression: compression)
    }

    static func photoQualityAssessment(from data: Data) -> PhotoQualityAssessment? {
        guard let image = UIImage(data: data) else { return nil }
        return photoQualityAssessment(from: image)
    }

    static func photoQualityAssessment(from image: UIImage) -> PhotoQualityAssessment? {
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

    static func jpegDataDownscaled(from image: UIImage, maxLongEdge: CGFloat, compression: CGFloat = 0.85) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return image.jpegData(compressionQuality: compression) }

        let scale = min(1, maxLongEdge / longest)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: compression)
    }

#if DEBUG
    static func sampleJPEG() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 640, height: 480)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)
            let cg = context.cgContext

            sampleSurfaceColor.setFill()
            context.fill(bounds)

            let backgroundSpace = CGColorSpaceCreateDeviceRGB()
            let backgroundColors = [
                sampleSurfaceColor.cgColor,
                samplePrimaryMutedColor.withAlphaComponent(0.72).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: backgroundSpace,
                colors: backgroundColors,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: bounds.midX, y: 40),
                    end: CGPoint(x: bounds.midX, y: bounds.maxY),
                    options: []
                )
            }

            sampleTableColor.setFill()
            context.fill(CGRect(x: 0, y: 352, width: 640, height: 128))

            sampleForegroundColor.withAlphaComponent(0.12).setFill()
            cg.fillEllipse(in: CGRect(x: 210, y: 344, width: 220, height: 44))

            let shade = UIBezierPath()
            shade.move(to: CGPoint(x: 226, y: 96))
            shade.addLine(to: CGPoint(x: 414, y: 96))
            shade.addLine(to: CGPoint(x: 464, y: 236))
            shade.addLine(to: CGPoint(x: 176, y: 236))
            shade.close()
            sampleBrassColor.setFill()
            shade.fill()
            sampleForegroundColor.withAlphaComponent(0.18).setStroke()
            shade.lineWidth = 8
            shade.stroke()

            sampleGlowColor.setFill()
            cg.fillEllipse(in: CGRect(x: 242, y: 128, width: 156, height: 64))

            cg.setLineCap(.round)
            cg.setLineWidth(18)
            sampleBrassDarkColor.setStroke()
            cg.move(to: CGPoint(x: 320, y: 236))
            cg.addLine(to: CGPoint(x: 320, y: 334))
            cg.strokePath()

            let base = UIBezierPath(
                roundedRect: CGRect(x: 230, y: 318, width: 180, height: 48),
                cornerRadius: 24
            )
            sampleBrassDarkColor.setFill()
            base.fill()

            sampleForegroundColor.withAlphaComponent(0.34).setStroke()
            cg.setLineWidth(8)
            cg.move(to: CGPoint(x: 356, y: 362))
            cg.addCurve(
                to: CGPoint(x: 492, y: 392),
                control1: CGPoint(x: 402, y: 374),
                control2: CGPoint(x: 444, y: 386)
            )
            cg.strokePath()
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
    }

    private static var samplePrimaryColor: UIColor {
        UIColor(named: "BrandPrimary") ?? .systemOrange
    }

    private static var sampleSurfaceColor: UIColor {
        UIColor(named: "Surface") ?? .systemBackground
    }

    private static var sampleForegroundColor: UIColor {
        UIColor(named: "Foreground") ?? .label
    }

    private static var samplePrimaryMutedColor: UIColor {
        UIColor(named: "BrandPrimaryMuted") ?? UIColor(red: 1.0, green: 0.94, blue: 0.89, alpha: 1)
    }

    private static var sampleTableColor: UIColor {
        UIColor(red: 0.93, green: 0.84, blue: 0.73, alpha: 1)
    }

    private static var sampleBrassColor: UIColor {
        UIColor(red: 0.86, green: 0.56, blue: 0.20, alpha: 1)
    }

    private static var sampleBrassDarkColor: UIColor {
        UIColor(red: 0.62, green: 0.36, blue: 0.13, alpha: 1)
    }

    private static var sampleGlowColor: UIColor {
        samplePrimaryColor.withAlphaComponent(0.28)
    }
#endif
}
