import Foundation
import AVFoundation

// Captures a melody/hum/instrument via the mic, OR holds an uploaded audio file,
// lets you preview it, and hands the bytes to the backend to build a cover from.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()

    @Published var isRecording = false
    @Published var hasClip = false
    @Published var isPreviewing = false
    @Published var clipName = ""
    @Published var sourceKind = ""      // "Hummed" or "Uploaded"
    @Published var status = ""
    private var recorder: AVAudioRecorder?
    private var previewPlayer: AVAudioPlayer?
    private(set) var clipURL: URL?

    func toggle() { isRecording ? stop() : requestAndStart() }

    private func requestAndStart() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: beginRecording()
            case .denied: status = "Microphone is off — enable it in Settings."
            default:
                AVAudioApplication.requestRecordPermission { ok in
                    Task { @MainActor in ok ? self.beginRecording() : (self.status = "Microphone permission needed.") }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { ok in
                Task { @MainActor in if ok { self.beginRecording() } }
            }
        }
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("rec-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.prepareToRecord()
            r.record()
            recorder = r
            clipURL = url
            isRecording = true
            hasClip = false
            status = ""
        } catch {
            status = "Couldn't start recording."
            isRecording = false
            print("record error:", error)
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
        hasClip = (clipURL != nil)
        clipName = "Recording"
        sourceKind = "Recorded"
    }

    // Reads a file chosen from the Files/audio picker into a local clip.
    func useUploadedFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            status = "Couldn't read that file."
            return
        }
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: dest)
            clipURL = dest
            hasClip = true
            clipName = url.lastPathComponent
            sourceKind = "Uploaded"
            status = ""
        } catch {
            status = "Couldn't save that file."
            print("upload write error:", error)
        }
    }

    // Preview (play/stop) the local clip so the user can hear what they'll base a song on.
    func previewToggle() {
        guard let url = clipURL else { return }
        if isPreviewing { previewPlayer?.stop(); isPreviewing = false; return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.delegate = self
            previewPlayer?.play()
            isPreviewing = true
        } catch { print("preview error:", error) }
    }

    func reset() {
        previewPlayer?.stop()
        clipURL = nil
        hasClip = false
        isPreviewing = false
        clipName = ""
        sourceKind = ""
        status = ""
    }

    func base64Clip() -> String? {
        guard let url = clipURL, let data = try? Data(contentsOf: url) else { return nil }
        return data.base64EncodedString()
    }

    // MARK: - Source-clip provenance (kept so a cover traces back to your audio)

    @Published var playingSource = ""   // filename of the source clip currently playing

    static func sourcesDir() -> URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sources")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func sourceURL(_ name: String) -> URL { sourcesDir().appendingPathComponent(name) }

    /// Copy the current clip into permanent storage; returns its filename.
    func persistSource() -> String? {
        guard let url = clipURL, let data = try? Data(contentsOf: url) else { return nil }
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let name = "src-\(UUID().uuidString).\(ext)"
        do { try data.write(to: AudioRecorder.sourceURL(name)); return name } catch { return nil }
    }

    /// Play/stop a saved source clip from the Vault.
    func toggleSource(_ name: String) {
        if playingSource == name { previewPlayer?.stop(); playingSource = ""; return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            previewPlayer = try AVAudioPlayer(contentsOf: AudioRecorder.sourceURL(name))
            previewPlayer?.delegate = self
            previewPlayer?.play()
            playingSource = name
        } catch { print("source play error:", error) }
    }
}

extension AudioRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPreviewing = false; self.playingSource = "" }
    }
}
