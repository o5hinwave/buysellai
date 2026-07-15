import AVFoundation
import UIKit

enum CameraStartResult {
    case ready
    case denied
    case failed
}

final class CameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "BuySellAI.CameraController")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDevice: AVCaptureDevice?
    private var configured = false
    private var photoDelegate: PhotoCaptureDelegate?

    func start() async -> CameraStartResult {
        let granted = await requestPermissionIfNeeded()
        guard granted else { return .denied }

        return await withCheckedContinuation { continuation in
            queue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    continuation.resume(returning: .ready)
                } catch {
                    continuation.resume(returning: .failed)
                }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func setTorch(enabled: Bool) {
        queue.async {
            guard let device = self.videoDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.torchMode = enabled ? .on : .off
            } catch {}
        }
    }

    func capturePhoto(flashOn: Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let settings = AVCapturePhotoSettings()
                if let pixelFormat = settings.availablePreviewPhotoPixelFormatTypes.first {
                    settings.previewPhotoFormat = [
                        kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
                        kCVPixelBufferWidthKey as String: 512,
                        kCVPixelBufferHeightKey as String: 512
                    ]
                }
                if self.photoOutput.supportedFlashModes.contains(.on) {
                    settings.flashMode = flashOn ? .on : .off
                }

                if let connection = self.photoOutput.connection(with: .video) {
                    let angle = CameraVideoRotation.angle(for: UIDevice.current.orientation)
                    if connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                }

                let delegate = PhotoCaptureDelegate { [weak self] result in
                    self?.photoDelegate = nil
                    switch result {
                    case .success(let data):
                        let downscaled = ImageTools.jpegDataDownscaled(from: data, maxLongEdge: 1600, compression: 0.85)
                        continuation.resume(returning: downscaled)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                self.photoDelegate = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    private func requestPermissionIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func configureIfNeeded() throws {
        guard configured == false else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        else {
            session.commitConfiguration()
            throw CameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }

        session.addInput(input)
        session.addOutput(photoOutput)

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        } catch {}

        videoDevice = device
        configured = true
        session.commitConfiguration()
    }
}

enum CameraError: LocalizedError {
    case noCamera
    case configurationFailed
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .noCamera: "Camera isn't available on this device.".localized
        case .configurationFailed: "Camera couldn't start.".localized
        case .captureFailed: "Photo couldn't be captured.".localized
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.captureFailed))
            return
        }
        completion(.success(data))
    }
}

enum CameraVideoRotation {
    static func angle(for orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft: 0
        case .landscapeRight: 180
        case .portraitUpsideDown: 270
        default: 90
        }
    }
}
