import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapToFocus: (CameraFocusTap) -> Void = { _ in }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.onTapToFocus = onTapToFocus
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.updateVideoRotation()
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        uiView.onTapToFocus = onTapToFocus
        uiView.updateVideoRotation()
    }
}

struct CameraFocusTap: Equatable {
    let viewPoint: CGPoint
    let devicePoint: CGPoint
}

final class PreviewView: UIView {
    var onTapToFocus: ((CameraFocusTap) -> Void)?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureTapToFocus()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTapToFocus()
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        (layer as? AVCaptureVideoPreviewLayer) ?? AVCaptureVideoPreviewLayer()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        updateVideoRotation()
    }

    func updateVideoRotation() {
        guard let connection = videoPreviewLayer.connection else { return }
        let orientation = window?.windowScene?.interfaceOrientation ?? .portrait
        let angle = CameraPreviewRotation.angle(for: orientation)
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    private func configureTapToFocus() {
        isUserInteractionEnabled = true
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        recognizer.cancelsTouchesInView = false
        addGestureRecognizer(recognizer)
    }

    @objc
    private func handleTapToFocus(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let viewPoint = recognizer.location(in: self)
        guard bounds.contains(viewPoint) else { return }
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint)
        onTapToFocus?(CameraFocusTap(viewPoint: viewPoint, devicePoint: devicePoint))
    }
}

enum CameraPreviewRotation {
    static func angle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft: 0
        case .landscapeRight: 180
        case .portraitUpsideDown: 270
        default: 90
        }
    }
}
