import AVFoundation
import os
import UIKit

enum CameraStartResult {
    case ready
    case denied
    case failed
}

struct CameraCapabilities: Equatable {
    let position: AVCaptureDevice.Position
    let isTorchAvailable: Bool
    let canSwitchCamera: Bool

    static let unavailable = CameraCapabilities(position: .back, isTorchAvailable: false, canSwitchCamera: false)
}

final class CameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    private static let queueKey = DispatchSpecificKey<Bool>()
    private let queue = DispatchQueue(label: "BuySellAI.CameraController")
    private let photoOutput = AVCapturePhotoOutput()
    private let logger = Logger(subsystem: "BuySellAI", category: "Camera")
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var configured = false
    private var photoDelegate: PhotoCaptureDelegate?

    override init() {
        super.init()
        queue.setSpecific(key: Self.queueKey, value: true)
    }

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
            self.stopRunningIfNeeded()
        }
    }

    func isTorchAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.videoDevice.map(Self.supportsTorch) ?? false)
            }
        }
    }

    func capabilities() async -> CameraCapabilities {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.currentCapabilities())
            }
        }
    }

    func setTorch(enabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let device = self.videoDevice, Self.supportsTorch(device) else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    defer { device.unlockForConfiguration() }
                    device.torchMode = enabled ? .on : .off
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func switchCamera() async -> CameraCapabilities {
        await withCheckedContinuation { continuation in
            queue.async {
                let nextPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
                guard
                    self.configured,
                    Self.hasCamera(position: nextPosition),
                    let device = Self.preferredCamera(position: nextPosition)
                else {
                    continuation.resume(returning: self.currentCapabilities())
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    self.session.beginConfiguration()
                    defer { self.session.commitConfiguration() }

                    if let videoInput = self.videoInput {
                        self.session.removeInput(videoInput)
                    }

                    guard self.session.canAddInput(input) else {
                        if let videoInput = self.videoInput, self.session.canAddInput(videoInput) {
                            self.session.addInput(videoInput)
                        }
                        continuation.resume(returning: self.currentCapabilities())
                        return
                    }

                    self.session.addInput(input)
                    self.videoInput = input
                    self.videoDevice = device
                    self.currentPosition = nextPosition
                    self.configureFocusAndExposure(for: device)
                    continuation.resume(returning: self.currentCapabilities())
                } catch {
                    self.logger.warning("Camera switch failed")
                    continuation.resume(returning: self.currentCapabilities())
                }
            }
        }
    }

    func focusAndExpose(at devicePoint: CGPoint) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let device = self.videoDevice else {
                    continuation.resume(returning: false)
                    return
                }

                do {
                    try device.lockForConfiguration()
                    defer { device.unlockForConfiguration() }

                    let point = Self.clampedDevicePoint(devicePoint)
                    var didApplyPoint = false

                    if device.isFocusPointOfInterestSupported {
                        device.focusPointOfInterest = point
                        if device.isFocusModeSupported(.autoFocus) {
                            device.focusMode = .autoFocus
                        } else if device.isFocusModeSupported(.continuousAutoFocus) {
                            device.focusMode = .continuousAutoFocus
                        }
                        didApplyPoint = true
                    }

                    if device.isExposurePointOfInterestSupported {
                        device.exposurePointOfInterest = point
                        if device.isExposureModeSupported(.continuousAutoExposure) {
                            device.exposureMode = .continuousAutoExposure
                        } else if device.isExposureModeSupported(.autoExpose) {
                            device.exposureMode = .autoExpose
                        }
                        didApplyPoint = true
                    }

                    continuation.resume(returning: didApplyPoint)
                } catch {
                    self.logger.warning("Camera tap focus and exposure skipped")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private static func supportsTorch(_ device: AVCaptureDevice) -> Bool {
        device.position == .back && device.hasTorch && device.isTorchAvailable
    }

    private static func supportsFlash(_ device: AVCaptureDevice) -> Bool {
        device.position == .back && device.hasFlash
    }

    func capturePhoto(flashOn: Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.configured, self.session.isRunning else {
                    continuation.resume(throwing: CameraError.captureFailed)
                    return
                }

                let settings = AVCapturePhotoSettings()
                if let pixelFormat = settings.availablePreviewPhotoPixelFormatTypes.first {
                    settings.previewPhotoFormat = [
                        kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
                        kCVPixelBufferWidthKey as String: 512,
                        kCVPixelBufferHeightKey as String: 512
                    ]
                }
                let supportsFlash = self.videoDevice.map(Self.supportsFlash) ?? false
                if supportsFlash, self.photoOutput.supportedFlashModes.contains(.on) {
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
                        self?.stopRunningSynchronously()
                        guard let downscaled = ImageTools.jpegDataDownscaled(from: data, maxLongEdge: 1600, compression: 0.85) else {
                            continuation.resume(throwing: CameraError.captureFailed)
                            return
                        }
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

    private func stopRunningSynchronously() {
        if DispatchQueue.getSpecific(key: Self.queueKey) == true {
            stopRunningIfNeeded()
            return
        }

        queue.sync {
            self.stopRunningIfNeeded()
        }
    }

    private func stopRunningIfNeeded() {
        if session.isRunning {
            session.stopRunning()
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
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let device = Self.preferredCamera(position: .back) else {
            throw CameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw CameraError.configurationFailed
        }

        session.addInput(input)
        session.addOutput(photoOutput)

        configureFocusAndExposure(for: device)

        videoInput = input
        videoDevice = device
        currentPosition = device.position
        configured = true
    }

    private func configureFocusAndExposure(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        } catch {
            logger.warning("Camera focus and exposure configuration skipped")
        }
    }

    private func currentCapabilities() -> CameraCapabilities {
        CameraCapabilities(
            position: currentPosition,
            isTorchAvailable: videoDevice.map(Self.supportsTorch) ?? false,
            canSwitchCamera: Self.hasCamera(position: .back) && Self.hasCamera(position: .front)
        )
    }

    private static func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInTripleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera
        ]

        for deviceType in deviceTypes {
            if let device = AVCaptureDevice.default(deviceType, for: .video, position: position) {
                return device
            }
        }

        return AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        ).devices.first
    }

    private static func hasCamera(position: AVCaptureDevice.Position) -> Bool {
        preferredCamera(position: position) != nil
    }

    private static func clampedDevicePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
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
