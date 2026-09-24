import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var model = RecorderModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var resumeAfterHistory = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: model.camera.session).ignoresSafeArea()

            VStack(spacing: 0) {
                Text("錄影 \(model.duration) 秒 · 就位 \(model.preparation) 秒")
                    .font(.footnote.weight(.semibold))
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
        .tint(.orange)
        .sheet(isPresented: $showHistory, onDismiss: {
            if resumeAfterHistory { Task { await model.enableCamera() } }
        }) {
            HistoryView(model: model)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(model: model)
        }
        .messageAlert(model: model, isActive: !showHistory && !showSettings)
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
                Text(model.phase == .preparing ? "正在啟動相機…" : "點中間按鈕啟用相機與麥克風")
                Text("使用後置相機與麥克風定時錄影").font(.caption)
            }
            .padding().background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        case .countdown:
            Text(model.cue).font(.system(size: 96, weight: .black, design: .rounded))
                .minimumScaleFactor(0.4).padding()
                .shadow(radius: 8)
                .accessibilityLabel("開拍倒數 \(model.cue)")
        case .recording:
            VStack {
                Label("錄影中", systemImage: "record.circle.fill").foregroundStyle(.red)
                Text("\(model.remaining)").font(.system(size: 72, weight: .bold, design: .monospaced))
                Text("秒剩餘")
            }
            .padding().background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        case .starting, .finishing:
            ProgressView(model.phase == .starting ? "開始錄影…" : "正在完成影片…")
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
            .accessibilityLabel("歷史錄影")
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
            .accessibilityLabel("設定")
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
        case .idle: "啟用相機與麥克風"
        case .ready: "開始倒數"
        case .countdown: "取消倒數"
        case .recording: "提前結束錄影"
        default: "處理中"
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
                Section("錄影時間") {
                    HStack {
                        ForEach([40, 60], id: \.self) { seconds in
                            Button("\(seconds) 秒") { model.duration = seconds }
                                .buttonStyle(.bordered)
                                .tint(model.duration == seconds ? .orange : .gray)
                        }
                    }
                    Stepper("自訂：\(model.duration) 秒", value: $model.duration, in: 1...600)
                    HStack {
                        Text("直接輸入秒數")
                        Spacer()
                        TextField("1–600", value: $model.duration, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .frame(width: 90).textFieldStyle(.roundedBorder)
                    }
                }
                Section {
                    Stepper("就位時間：\(model.preparation) 秒", value: $model.preparation, in: 0...20)
                    Picker("3、2、1 的速度", selection: $model.fastBeat) {
                        Text("快 · 0.4 秒").tag(0.4)
                        Text("標準 · 0.5 秒").tag(0.5)
                        Text("慢 · 0.7 秒").tag(0.7)
                    }
                } header: {
                    Text("開拍倒數")
                } footer: {
                    Text("就位後顯示 5、4（每個 1 秒），接著加快 3、2、1。倒數配有系統提示音，請先確認手機音量與靜音設定。倒數不計入錄影時間。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("完成") { dismiss() }.disabled(!(1...600).contains(model.duration)) }
            .interactiveDismissDisabled(!(1...600).contains(model.duration))
        }
    }
}

private struct HistoryView: View {
    @ObservedObject var model: RecorderModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.clips.isEmpty {
                    ContentUnavailableView("還沒有錄影", systemImage: "video.slash",
                                           description: Text("完成錄影後會出現在這裡。"))
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
            .navigationTitle("歷史錄影")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: URL.self) { url in
                PlaybackView(url: url, model: model)
            }
            .toolbar { Button("完成") { dismiss() }.disabled(model.saving) }
            .safeAreaInset(edge: .bottom) {
                Text("影片先保留在此裝置的 App 內。")
                    .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 8)
            }
        }
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
        alert("提示", isPresented: Binding(get: { isActive && model.message != nil },
                                          set: { if !$0 { model.message = nil } })) {
            if model.needsSettings {
                Button("開啟設定") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Button("確定", role: .cancel) { model.needsSettings = false }
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
            Button(model.saving ? "儲存中…" : "儲存到相簿") {
                Task { await model.save(url) }
            }.buttonStyle(.borderedProminent).disabled(model.saving)
            Text("只有儲存時才會要求新增至相簿的權限。")
                .font(.footnote).foregroundStyle(.secondary)
        }.padding()
            .navigationTitle("影片回放")
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
