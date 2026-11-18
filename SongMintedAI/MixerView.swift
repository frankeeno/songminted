import SwiftUI
import AVFoundation

// ============================================================
// Stem Mixer (Pro) — load the separated stems, then mute / solo / slide the
// volume of each instrument in sync, and export the custom balance to a file.
// Built on AVAudioEngine: one player node per stem into the main mixer.
// ============================================================

// One instrument track in the mixer.
final class StemTrack: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    @Published var volume: Float = 0.85
    @Published var muted = false
    @Published var solo = false
    fileprivate let node = AVAudioPlayerNode()
    fileprivate var file: AVAudioFile?
    init(name: String, url: URL) { self.name = name; self.url = url }
}

@MainActor
final class StemMixer: ObservableObject {
    @Published var tracks: [StemTrack] = []
    @Published var loading = true
    @Published var isPlaying = false
    @Published var progress: Double = 0          // 0…1 through the song
    @Published var duration: Double = 0          // seconds
    @Published var exporting = false
    @Published var error: String?

    private let engine = AVAudioEngine()
    private var sampleRate: Double = 44_100
    private var totalFrames: AVAudioFramePosition = 0
    private var seekFrame: AVAudioFramePosition = 0
    private var timer: Timer?

    // MARK: Load + prepare

    func load(_ stems: [(name: String, url: URL)]) async {
        loading = true
        var built: [StemTrack] = []
        for s in stems {
            let t = StemTrack(name: s.name, url: s.url)
            do {
                let local = try await download(s.url)
                t.file = try AVAudioFile(forReading: local)
                built.append(t)
            } catch { print("stem load error:", error) }
        }
        tracks = built
        setupEngine()
        loading = false
    }

    private func download(_ url: URL) async throws -> URL {
        let (data, _) = try await URLSession.shared.data(from: url)
        let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        try data.write(to: dest)
        return dest
    }

    private func setupEngine() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        for t in tracks {
            guard let f = t.file else { continue }
            engine.attach(t.node)
            engine.connect(t.node, to: engine.mainMixerNode, format: f.processingFormat)
            sampleRate = f.processingFormat.sampleRate
            totalFrames = max(totalFrames, f.length)
        }
        duration = sampleRate > 0 ? Double(totalFrames) / sampleRate : 0
        applyMix()
        do { try engine.start() } catch { self.error = "Couldn't start audio engine." }
    }

    // MARK: Transport

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard !tracks.isEmpty else { return }
        if !engine.isRunning { try? engine.start() }
        scheduleFrom(seekFrame)
        let start = AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.12))
        for t in tracks { t.node.play(at: start) }
        isPlaying = true
        startTimer()
    }

    func pause() {
        seekFrame = currentFrame()
        for t in tracks { t.node.stop() }
        isPlaying = false
        stopTimer()
    }

    func seek(to fraction: Double) {
        let wasPlaying = isPlaying
        if wasPlaying { for t in tracks { t.node.stop() }; stopTimer(); isPlaying = false }
        seekFrame = AVAudioFramePosition(Double(totalFrames) * min(max(fraction, 0), 1))
        progress = min(max(fraction, 0), 1)
        if wasPlaying { play() }
    }

    private func scheduleFrom(_ frame: AVAudioFramePosition) {
        for t in tracks {
            guard let f = t.file else { continue }
            t.node.stop()
            let remaining = f.length - frame
            guard remaining > 0 else { continue }
            t.node.scheduleSegment(f, startingFrame: frame,
                                   frameCount: AVAudioFrameCount(remaining), at: nil)
        }
    }

    private func currentFrame() -> AVAudioFramePosition {
        guard let node = tracks.first?.node, let rt = node.lastRenderTime,
              let pt = node.playerTime(forNodeTime: rt) else { return seekFrame }
        return min(totalFrames, seekFrame + pt.sampleTime)
    }

    // MARK: Mix — mute / solo / volume all resolve to a node volume

    func applyMix() {
        let anySolo = tracks.contains { $0.solo }
        for t in tracks {
            let audible = !t.muted && (!anySolo || t.solo)
            t.node.volume = audible ? t.volume : 0
        }
    }

    // MARK: Timer for the scrubber

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let f = self.currentFrame()
                if self.totalFrames > 0 { self.progress = Double(f) / Double(self.totalFrames) }
                if f >= self.totalFrames { self.pause(); self.seekFrame = 0; self.progress = 0 }
            }
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    // MARK: Export the current balance to a file (offline render)

    func exportMix() async -> URL? {
        guard !tracks.isEmpty else { return nil }
        exporting = true
        defer { exporting = false }
        pause()
        engine.stop()

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        do {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
            try engine.start()
            for t in tracks {
                guard let f = t.file else { continue }
                t.node.stop()
                t.node.scheduleFile(f, at: nil, completionHandler: nil)
                t.node.play()
            }
            applyMix()

            let out = FileManager.default.temporaryDirectory.appendingPathComponent("SongMinted Mix.m4a")
            try? FileManager.default.removeItem(at: out)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let outFile = try AVAudioFile(forWriting: out, settings: settings,
                                          commonFormat: .pcmFormatFloat32, interleaved: false)
            let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                          frameCapacity: 4096)!
            while engine.manualRenderingSampleTime < totalFrames {
                let remaining = totalFrames - engine.manualRenderingSampleTime
                let toRender = min(AVAudioFrameCount(remaining), buffer.frameCapacity)
                let status = try engine.renderOffline(toRender, to: buffer)
                if status == .success { try outFile.write(from: buffer) } else { break }
            }

            engine.stop()
            engine.disableManualRenderingMode()
            try? engine.start()
            seekFrame = 0; progress = 0
            return out
        } catch {
            self.error = "Export failed."
            engine.disableManualRenderingMode()
            try? engine.start()
            return nil
        }
    }

    func teardown() {
        stopTimer()
        for t in tracks { t.node.stop() }
        engine.stop()
    }
}

// MARK: - View

struct MixerView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let stems: [(name: String, url: URL)]
    @StateObject private var mixer = StemMixer()
    @State private var shareItem: ShareItem?

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Mixer").font(.system(size: 24, weight: .bold))
                    Text("PRO").font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.obsidian)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Brand.gradientGold).clipShape(Capsule())
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(Brand.muted)
                    }
                }
                Text("Mute, solo and balance each instrument, then save your custom mix.")
                    .font(.system(size: 14)).foregroundColor(Brand.muted)

                if mixer.loading {
                    HStack(spacing: 10) {
                        ProgressView().tint(Brand.emerald)
                        Text("Loading stems…").font(.system(size: 14)).foregroundColor(Brand.muted)
                    }.padding(.top, 8)
                } else {
                    // Transport
                    HStack(spacing: 16) {
                        Button { mixer.togglePlay() } label: {
                            Image(systemName: mixer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22)).foregroundColor(Brand.obsidian)
                                .frame(width: 54, height: 54).background(Brand.gradient).clipShape(Circle())
                        }
                        VStack(spacing: 4) {
                            Slider(value: Binding(get: { mixer.progress },
                                                  set: { mixer.seek(to: $0) }), in: 0...1)
                                .tint(Brand.emerald)
                            HStack {
                                Text(time(mixer.progress * mixer.duration)).font(.system(size: 11)).foregroundColor(Brand.muted)
                                Spacer()
                                Text(time(mixer.duration)).font(.system(size: 11)).foregroundColor(Brand.muted)
                            }
                        }
                    }

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(mixer.tracks) { t in
                                StemChannel(track: t) { mixer.applyMix() }
                            }
                        }
                    }

                    // Save mix (Pro)
                    Button {
                        Task {
                            if let url = await mixer.exportMix() {
                                shareItem = ShareItem(url: url)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if mixer.exporting { ProgressView().tint(Brand.obsidian) }
                            else { Image(systemName: "square.and.arrow.down") }
                            Text(mixer.exporting ? "Rendering mix…" : "Save mix")
                        }
                        .font(.system(size: 17, weight: .bold)).foregroundColor(Brand.obsidian)
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Brand.gradientGold).clipShape(Capsule())
                    }
                    .disabled(mixer.exporting)
                }

                if let e = mixer.error {
                    Text(e).font(.system(size: 13)).foregroundColor(.red)
                }
                Spacer()
            }
            .padding()
        }
        .task { await mixer.load(stems) }
        .onDisappear { mixer.teardown() }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
    }

    private func time(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let t = Int(s); return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// One channel strip: name, mute, solo, volume.
private struct StemChannel: View {
    @ObservedObject var track: StemTrack
    let onChange: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "waveform").foregroundColor(Brand.teal)
                Text(track.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                toggle("M", track.muted, Brand.gold) { track.muted.toggle(); onChange() }
                toggle("S", track.solo, Brand.emerald) { track.solo.toggle(); onChange() }
            }
            HStack(spacing: 10) {
                Image(systemName: "speaker.fill").font(.system(size: 12)).foregroundColor(Brand.muted)
                Slider(value: Binding(get: { Double(track.volume) },
                                      set: { track.volume = Float($0); onChange() }), in: 0...1)
                    .tint(track.muted ? Brand.muted : Brand.emerald)
                    .disabled(track.muted)
                Text("\(Int(track.volume * 100))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Brand.muted).frame(width: 34, alignment: .trailing)
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.stroke)))
    }

    private func toggle(_ label: String, _ on: Bool, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 13, weight: .heavy))
                .foregroundColor(on ? Brand.obsidian : color)
                .frame(width: 30, height: 30)
                .background(Circle().fill(on ? color : Color.clear)
                    .overlay(Circle().stroke(color, lineWidth: 1.5)))
        }
    }
}
