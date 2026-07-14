import UIKit

enum ImageTools {
    static func jpegDataDownscaled(from data: Data, maxLongEdge: CGFloat, compression: CGFloat = 0.85) -> Data {
        guard let image = UIImage(data: data) else { return data }
        return jpegDataDownscaled(from: image, maxLongEdge: maxLongEdge, compression: compression) ?? data
    }

    static func jpegDataDownscaled(from image: UIImage, maxLongEdge: CGFloat, compression: CGFloat = 0.85) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return image.jpegData(compressionQuality: compression) }

        let scale = min(1, maxLongEdge / longest)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: compression)
    }

    static func sampleJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480))
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 210, y: 120, width: 220, height: 220))
            UIColor.black.withAlphaComponent(0.7).setStroke()
            context.cgContext.setLineWidth(12)
            context.cgContext.stroke(CGRect(x: 250, y: 340, width: 140, height: 76))
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
    }
}

