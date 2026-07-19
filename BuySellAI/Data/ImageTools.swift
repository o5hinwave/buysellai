import UIKit

enum ImageTools {
    static func jpegDataDownscaled(from data: Data, maxLongEdge: CGFloat, compression: CGFloat = 0.85) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegDataDownscaled(from: image, maxLongEdge: maxLongEdge, compression: compression)
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
}
