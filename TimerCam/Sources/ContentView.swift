import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var model = RecorderModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var resumeAfterHistory = false
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: model.camera.session).ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Record \(model.duration)s · Get ready \(model.preparation)s")
                    .font(.app(.footnote))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(.top, 8)
                Spacer()
                statusOverlay
                Spacer()
                controlBar
            }
            .foregroundStyle(.white)
        }
        .font(.app())
        .tint(.orange)
        .sheet(isPresented: $showHistory, onDismiss: {
            if resumeAfterHistory { Task { await model.enableCamera() } }
        }) {
            HistoryView(model: model)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(model: model)
        }
        .fullScreenCover(isPresented: Binding(get: { !hasSeenIntro }, set: { hasSeenIntro = !$0 })) {
            IntroView { hasSeenIntro = true }
        }
        .messageAlert(model: model, isActive: hasSeenIntro && !showHistory && !showSettings)
        .onChange(of: scenePhase) { _, phase in
            // Permission sheets temporarily make the scene inactive: only suspend on background.
            if phase == .background { model.deactivate() }
        }
    }

    @ViewBuilder private var statusOverlay: some View {
        switch model.phase {
        case .idle, .preparing:
            VStack(spacing: 12) {
                Image(systemName: "camera.fill").font(.largeTitle)
                Text(model.phase == .preparing ? "Starting camera…" : "Tap the center button to turn on the camera and microphone")
                Text("Timed recording with the back camera and microphone").font(.app(.caption))
            }
            .padding().background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        case .countdown:
            Text(model.cue).font(.app(.largeTitle, size: 96))
                .minimumScaleFactor(0.4).padding()
                .shadow(radius: 8)
                .accessibilityLabel("Countdown \(model.cue)")
        case .recording:
            VStack {
                Label("Recording", systemImage: "record.circle.fill").foregroundStyle(.red)
                Text("\(model.remaining)").font(.app(.largeTitle, size: 72)).monospacedDigit()
                Text("seconds left")
            }
            .padding().background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        case .starting, .finishing:
            ProgressView(model.phase == .starting ? "Starting recording…" : "Finishing video…")
                .tint(.white).padding()
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        case .ready:
            EmptyView()
        }
    }

    private var controlBar: some View {
        HStack {
            Button {
                resumeAfterHistory = model.phase == .ready
                model.deactivate()
                showHistory = true
            } label: {
                ClipThumbnail(url: model.clips.first)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.8), lineWidth: 2))
            }
            .accessibilityLabel("Recording history")
            .disabled(model.busy)
            .frame(maxWidth: .infinity)

            ShutterButton(model: model)
                .frame(maxWidth: .infinity)

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("Settings")
            .disabled(model.busy)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 20)
        .background(Color.black.opacity(0.35).ignoresSafeArea(edges: .bottom))
    }
}

private struct ShutterButton: View {
    @ObservedObject var model: RecorderModel

    var body: some View {
        Button(action: tap) {
            ZStack {
                Circle().stroke(.white, lineWidth: 5).frame(width: 78, height: 78)
                switch model.phase {
                case .idle:
                    Image(systemName: "camera.fill").font(.title).foregroundStyle(.white)
                case .ready:
                    Circle().fill(.red).frame(width: 64, height: 64)
                case .countdown, .recording:
                    RoundedRectangle(cornerRadius: 8).fill(.red).frame(width: 32, height: 32)
                case .preparing, .starting, .finishing:
                    ProgressView().tint(.white)
                }
            }
        }
        .disabled([.preparing, .starting, .finishing].contains(model.phase)
                  || (model.phase == .ready && !(1...600).contains(model.duration)))
        .accessibilityLabel(label)
    }

    private var label: String {
        switch model.phase {
        case .idle: "Turn on camera and microphone"
        case .ready: "Start countdown"
        case .countdown: "Cancel countdown"
        case .recording: "Stop recording early"
        default: "Working"
        }
    }

    private func tap() {
        switch model.phase {
        case .idle: Task { await model.enableCamera() }
        case .ready: model.start()
        case .countdown, .recording: model.cancelOrStop()
        default: break
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: RecorderModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Recording length") {
                    HStack {
                        ForEach([40, 60], id: \.self) { seconds in
                            Button("\(seconds)s") { model.duration = seconds }
                                .buttonStyle(.bordered)
                                .tint(model.duration == seconds ? .orange : .gray)
                        }
                    }
                    Stepper("Custom: \(model.duration)s", value: $model.duration, in: 1...600)
                    HStack {
                        Text("Seconds")
                        Spacer()
                        TextField("1–600", value: $model.duration, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .frame(width: 90).textFieldStyle(.roundedBorder)
                    }
                }
                Section {
                    Stepper("Get ready: \(model.preparation)s", value: $model.preparation, in: 0...20)
                    Picker("3-2-1 speed", selection: $model.fastBeat) {
                        Text("Fast · 0.4s").tag(0.4)
                        Text("Normal · 0.5s").tag(0.5)
                        Text("Slow · 0.7s").tag(0.7)
                    }
                } header: {
                    Text("Countdown")
                } footer: {
                    Text("After the get-ready time, 5 and 4 show for 1 second each, then 3, 2, 1 speed up. Each number plays a system sound, so check your volume and silent mode. The countdown doesn't count toward the recording length.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() }.disabled(!(1...600).contains(model.duration)) }
            .interactiveDismissDisabled(!(1...600).contains(model.duration))
        }
        .font(.app())
    }
}

private struct HistoryView: View {
    @ObservedObject var model: RecorderModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.clips.isEmpty {
                    ContentUnavailableView("No recordings yet", systemImage: "video.slash",
                                           description: Text("Finished recordings show up here."))
                } else {
                    List(model.clips, id: \.self) { url in
                        NavigationLink(value: url) {
                            HStack(spacing: 12) {
                                ClipThumbnail(url: url)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(clipTitle(url))
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: URL.self) { url in
                PlaybackView(url: url, model: model)
            }
            .toolbar { Button("Done") { dismiss() }.disabled(model.saving) }
            .safeAreaInset(edge: .bottom) {
                Text("Videos are kept in the app on this device.")
                    .font(.app(.footnote)).foregroundStyle(.secondary).padding(.bottom, 8)
            }
        }
        .font(.app())
        .interactiveDismissDisabled(model.saving)
        .messageAlert(model: model, isActive: true)
    }

    private func clipTitle(_ url: URL) -> String {
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        return date.formatted(date: .abbreviated, time: .standard)
    }
}

private struct ClipThumbnail: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle").foregroundStyle(.white)
            }
        }
        .task(id: url) {
            image = nil
            guard let url else { return }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 200, height: 200)
            if let cgImage = try? await generator.image(at: .zero).image {
                image = UIImage(cgImage: cgImage)
            }
        }
    }
}

private extension View {
    func messageAlert(model: RecorderModel, isActive: Bool) -> some View {
        alert("Timer Cam", isPresented: Binding(get: { isActive && model.message != nil },
                                          set: { if !$0 { model.message = nil } })) {
            if model.needsSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Button("OK", role: .cancel) { model.needsSettings = false }
        } message: { Text(model.message ?? "") }
    }
}

private struct PlaybackView: View {
    let url: URL
    @ObservedObject var model: RecorderModel
    @State private var player: AVPlayer

    init(url: URL, model: RecorderModel) {
        self.url = url
        self.model = model
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VStack(spacing: 20) {
            VideoPlayer(player: player)
            Button(model.saving ? "Saving…" : "Save to Photos") {
                Task { await model.save(url) }
            }.buttonStyle(.borderedProminent).disabled(model.saving)
            Text("Photo library access is only requested when you save.")
                .font(.app(.footnote)).foregroundStyle(.secondary)
        }.padding()
            .navigationTitle("Playback")
            .navigationBarBackButtonHidden(model.saving)
            .onDisappear { player.pause() }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}
