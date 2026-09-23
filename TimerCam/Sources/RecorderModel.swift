import SwiftUI
import AVFoundation
import AudioToolbox
import Photos
import Combine

@MainActor
final class RecorderModel: ObservableObject {
    enum Phase { case idle, preparing, ready, countdown, starting, recording, finishing }
    @Published var phase: Phase = .idle
    @Published var duration = 40
    @Published var preparation = 3
    @Published var fastBeat = 0.5
    @Published var cue = ""
    @Published var remaining = 40
    @Published var clips: [URL] = []
    @Published var message: String?
    @Published var needsSettings = false
    @Published var saving = false
    let camera = CameraRecorder()
    private var countdownTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var active = true
    private var takeDuration = 40
    private var generation = 0

    var busy: Bool { [.preparing, .countdown, .starting, .recording, .finishing].contains(phase) }

    init() {
        refreshClips()
        camera.onStart = { [weak self] in
            guard let self else { return }
            guard self.active, self.phase == .starting else { self.camera.stop(); return }
            self.phase = .recording
            let start = ProcessInfo.processInfo.systemUptime
            self.clockTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    let elapsed = ProcessInfo.processInfo.systemUptime - start
                    self.remaining = max(0, Int(ceil(Double(self.takeDuration) - elapsed)))
                    // The capture output, not this UI clock, enforces the recording limit.
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }
        camera.onFinish = { [weak self] result in
            guard let self else { return }
            self.clockTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
            self.phase = self.active ? .ready : .idle
            switch result {
            case .success: self.refreshClips()
            case .failure(let error): self.message = error.localizedDescription
            }
        }
        camera.onInterruption = { [weak self] in
            self?.deactivate()
            self?.message = "錄影被系統中斷。已完成的片段會保留；請重新啟用相機。"
        }
    }

    func enableCamera() async {
        guard !busy else { return }
        active = true
        generation += 1
        let token = generation
        phase = .preparing
        needsSettings = false
        for type in [AVMediaType.video, .audio] {
            let status = AVCaptureDevice.authorizationStatus(for: type)
            let granted: Bool
            if status == .notDetermined { granted = await AVCaptureDevice.requestAccess(for: type) }
            else { granted = status == .authorized }
            guard active, generation == token else { return }
            guard granted else {
                phase = .idle
                needsSettings = status != .restricted
                message = type == .video ? "需要相機權限才能錄影。請到設定允許相機存取。" : "需要麥克風權限才能收錄現場聲音。請到設定允許麥克風存取。"
                return
            }
        }
        camera.prepare { [weak self] result in
            guard let self, self.active, self.generation == token else { return }
            switch result {
            case .success: self.phase = .ready
            case .failure(let error): self.phase = .idle; self.message = error.localizedDescription
            }
        }
    }

    func start() {
        guard phase == .ready, (1...600).contains(duration) else { return }
        takeDuration = duration
        remaining = duration
        phase = .countdown
        UIApplication.shared.isIdleTimerDisabled = true
        countdownTask = Task { [weak self] in
            guard let self else { return }
            do {
                if self.preparation > 0 {
                    for second in stride(from: self.preparation, through: 1, by: -1) {
                        self.cue = "準備 \(second)"
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
                for number in stride(from: 5, through: 1, by: -1) {
                    try Task.checkCancellation()
                    self.cue = "\(number)"
                    AudioServicesPlaySystemSound(1104)
                    let interval = number >= 4 ? 1.0 : self.fastBeat
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                try Task.checkCancellation()
                self.cue = ""
                self.phase = .starting
                self.camera.record(seconds: self.takeDuration)
            } catch { /* User cancelled the cue, or the app left the foreground. */ }
        }
    }

    func cancelOrStop() {
        countdownTask?.cancel()
        cue = ""
        if phase == .countdown { phase = .ready; UIApplication.shared.isIdleTimerDisabled = false }
        else if phase == .recording || phase == .starting { phase = .finishing; camera.stop() }
    }

    func deactivate() {
        active = false
        generation += 1
        countdownTask?.cancel()
        clockTask?.cancel()
        cue = ""
        phase = [.recording, .starting, .finishing].contains(phase) ? .finishing : .idle
        camera.suspend()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func refreshClips() {
        UIApplication.shared.isIdleTimerDisabled = false
        guard let folder = try? CameraRecorder.recordingsDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]) else { return }
        clips = files.filter { $0.pathExtension == "mov" }.sorted {
            let first = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let second = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return first > second
        }
    }

    func save(_ url: URL) async {
        guard !saving else { return }
        saving = true
        needsSettings = false
        defer { saving = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            needsSettings = true
            message = "尚未允許新增影片到相簿。影片仍保留在 App 內，可前往設定開啟權限。"
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            message = "影片已儲存到相簿。"
        } catch { message = "儲存失敗：\(error.localizedDescription)。影片仍保留在 App 內。" }
    }
}
