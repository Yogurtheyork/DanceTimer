import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var model = RecorderModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedClip: Clip?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        CameraPreview(session: model.camera.session)
                        Color.black.opacity(0.15)
                        if model.phase == .idle || model.phase == .preparing {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill").font(.largeTitle)
                                Text(model.phase == .preparing ? "正在啟動相機…" : "準備好你的下一個回合")
                                Text("使用後置相機與麥克風錄製練舞影片")
                                    .font(.caption)
                            }
                        } else if model.phase == .countdown {
                            Text(model.cue).font(.system(size: 72, weight: .black, design: .rounded))
                                .minimumScaleFactor(0.4).padding()
                                .accessibilityLabel("進場倒數 \(model.cue)")
                        } else if model.phase == .recording {
                            VStack {
                                Label("錄影中", systemImage: "record.circle.fill").foregroundStyle(.red)
                                Text("\(model.remaining)").font(.system(size: 64, weight: .bold, design: .monospaced))
                                Text("秒剩餘")
                            }
                        } else if model.phase == .starting || model.phase == .finishing {
                            ProgressView(model.phase == .starting ? "開始錄影…" : "正在完成影片…").tint(.white)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityElement(children: .contain)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("錄影時間").font(.headline)
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
                        Divider()
                        Text("進場倒數").font(.headline)
                        Stepper("就位時間：\(model.preparation) 秒", value: $model.preparation, in: 0...20)
                        Picker("3、2、1 的速度", selection: $model.fastBeat) {
                            Text("快 · 0.4 秒").tag(0.4)
                            Text("標準 · 0.5 秒").tag(0.5)
                            Text("慢 · 0.7 秒").tag(0.7)
                        }
                        Text("就位後顯示 5、4（每個 1 秒），接著加快 3、2、1。倒數配有系統提示音，請先確認手機音量與靜音設定。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .disabled(model.busy)

                    if model.phase == .idle {
                        Button("啟用相機與麥克風") { Task { await model.enableCamera() } }
                            .buttonStyle(PrimaryButtonStyle())
                    } else if model.phase == .ready {
                        Button("開始進場倒數") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            model.start()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!(1...600).contains(model.duration))
                    } else if model.phase == .countdown || model.phase == .recording {
                        Button(model.phase == .countdown ? "取消倒數" : "提前結束錄影") { model.cancelOrStop() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    Text("倒數不計入錄影時間。影片先保留在此裝置的 App 內。")
                        .font(.footnote).foregroundStyle(.secondary)

                    if !model.clips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("練習影片").font(.title2.bold())
                            ForEach(model.clips, id: \.self) { url in
                                Button {
                                    model.deactivate()
                                    selectedClip = Clip(url: url)
                                } label: {
                                    Label(clipTitle(url), systemImage: "play.rectangle.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading).padding()
                                }.buttonStyle(.bordered)
                            }
                        }.disabled(model.busy)
                    }
                }.padding()
            }
            .navigationTitle("Dance Timer")
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(item: $selectedClip) { clip in
                PlaybackView(url: clip.url, model: model)
            }
            .alert("提示", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                if model.needsSettings {
                    Button("開啟設定") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Button("確定", role: .cancel) { model.needsSettings = false }
            } message: { Text(model.message ?? "") }
            .onChange(of: scenePhase) { _, phase in
                // Permission sheets temporarily make the scene inactive: only suspend on background.
                if phase == .background { model.deactivate() }
            }
        }.tint(.orange)
    }

    private func clipTitle(_ url: URL) -> String {
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        return date.formatted(date: .abbreviated, time: .standard)
    }
}

private struct Clip: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding()
            .background(.orange.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.black)
    }
}

private struct PlaybackView: View {
    let url: URL
    @ObservedObject var model: RecorderModel
    @State private var player: AVPlayer
    @Environment(\.dismiss) private var dismiss

    init(url: URL, model: RecorderModel) {
        self.url = url
        self.model = model
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VideoPlayer(player: player)
                Button(model.saving ? "儲存中…" : "儲存到相簿") {
                    Task {
                        await model.save(url)
                        // Present the result alert on the underlying screen after dismissing.
                        dismiss()
                    }
                }.buttonStyle(.borderedProminent).disabled(model.saving)
                Text("只有儲存時才會要求新增至相簿的權限。")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding()
                .navigationTitle("回合回放")
                .toolbar { Button("完成") { dismiss() }.disabled(model.saving) }
                .interactiveDismissDisabled(model.saving)
                .onDisappear { player.pause() }
        }
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
