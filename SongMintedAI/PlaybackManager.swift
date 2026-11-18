import SwiftUI
import AVFoundation

// Owns audio playback app-wide so a song keeps playing after the full-screen
// player is dismissed (back button). The player view just drives this manager.
@MainActor
final class PlaybackManager: ObservableObject {
    static let shared = PlaybackManager()

    @Published var song: Song?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    private var player: AVPlayer?
    private var observer: Any?
    private var endObserver: NSObjectProtocol?

    /// Start (or resume) a song. If it's already the current one, keep playing
    /// at its position — only restart when it's genuinely a different track.
    func load(_ newSong: Song, restart: Bool = false) {
        if !restart, song?.id == newSong.id, player != nil {
            if !isPlaying { player?.play(); isPlaying = true }
            return
        }
        clearObserver()
        song = newSong
        currentTime = 0; duration = 0
        guard let url = newSong.audioURL else { player = nil; return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: url)
        player = p
        observer = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            guard let self else { return }
            self.currentTime = t.seconds
            if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
        }
        // When the song finishes, rewind to the start so it can be replayed.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.player?.seek(to: .zero)
                self?.currentTime = 0
                self?.isPlaying = false
            }
        }
        p.play(); isPlaying = true
    }

    func toggle() {
        guard let p = player else { return }
        if isPlaying { p.pause() } else { p.play() }
        isPlaying.toggle()
    }
    func pause() { player?.pause(); isPlaying = false }
    func seek(to s: Double) {
        let target = max(0, s)
        player?.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
    }
    func skip(_ s: Double) { seek(to: max(0, min(duration, currentTime + s))) }

    func stop() {
        player?.pause(); clearObserver(); player = nil; song = nil
        isPlaying = false; currentTime = 0; duration = 0
    }

    private func clearObserver() {
        if let o = observer { player?.removeTimeObserver(o); observer = nil }
        if let e = endObserver { NotificationCenter.default.removeObserver(e); endObserver = nil }
    }
}
