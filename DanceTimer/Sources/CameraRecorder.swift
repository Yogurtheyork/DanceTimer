import AVFoundation
import Foundation

// All capture-session mutations run on this serial queue, never on the UI thread.
// Use Swift 5 language mode and Nonisolated default actor isolation (see README).
final class CameraRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dance.camera")
    private let output = AVCaptureMovieFileOutput()
    private var configured = false
    private var observers: [NSObjectProtocol] = []
    var onStart: (() -> Void)?
    var onFinish: ((Result<URL, Error>) -> Void)?
    var onInterruption: (() -> Void)?

    override init() {
        super.init()
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: .main) { [weak self] _ in
                self?.onInterruption?()
            })
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func prepare(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            do {
                if !self.configured {
                    self.session.beginConfiguration()
                    do {
                        self.session.sessionPreset = .high
                        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                              let microphone = AVCaptureDevice.default(for: .audio) else {
                            throw RecorderError.unavailable
                        }
                        let inputs = try [AVCaptureDeviceInput(device: camera), AVCaptureDeviceInput(device: microphone)]
                        for input in inputs {
                            guard self.session.canAddInput(input) else { throw RecorderError.unavailable }
                            self.session.addInput(input)
                        }
                        guard self.session.canAddOutput(self.output) else { throw RecorderError.unavailable }
                        self.session.addOutput(self.output)
                        self.session.commitConfiguration()
                        self.configured = true
                    } catch {
                        self.session.inputs.forEach { self.session.removeInput($0) }
                        self.session.outputs.forEach { self.session.removeOutput($0) }
                        self.session.commitConfiguration()
                        throw error
                    }
                }
                if !self.session.isRunning { self.session.startRunning() }
                guard self.session.isRunning else { throw RecorderError.unavailable }
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func record(seconds: Int) {
        queue.async {
            guard self.session.isRunning, !self.output.isRecording else {
                DispatchQueue.main.async { self.onFinish?(.failure(RecorderError.unavailable)) }
                return
            }
            do {
                let folder = try Self.recordingsDirectory()
                let url = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                if let connection = self.output.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                self.output.maxRecordedDuration = CMTime(seconds: Double(seconds), preferredTimescale: 600)
                self.output.startRecording(to: url, recordingDelegate: self)
            } catch {
                DispatchQueue.main.async { self.onFinish?(.failure(error)) }
            }
        }
    }

    func stop() {
        queue.async { if self.output.isRecording { self.output.stopRecording() } }
    }

    func suspend() {
        queue.async {
            if self.output.isRecording { self.output.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async { self.onStart?() }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Reaching maxRecordedDuration may supply an error while still producing a valid movie.
        let nsError = error as NSError?
        let succeeded = error == nil || (nsError?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true)
        if !succeeded { try? FileManager.default.removeItem(at: url) }
        DispatchQueue.main.async {
            if succeeded { self.onFinish?(.success(url)) }
            else { self.onFinish?(.failure(error ?? RecorderError.unavailable)) }
        }
    }

    static func recordingsDirectory() throws -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    enum RecorderError: LocalizedError {
        case unavailable
        var errorDescription: String? { "無法啟動相機或麥克風。請在實體 iPhone 上確認權限，並關閉其他使用相機的功能後重試。" }
    }
}
