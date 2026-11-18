import SwiftUI
import AVFoundation

// MARK: - Music-video visualizer
// Default (free): the cover art with a slow Ken-Burns push-in, moving brand
// gradient, animated equalizer, and title, playing the song's audio.
// Pro upgrade: tap "Cinematic video" to render a real AI clip (Higgsfield) that
// plays behind the song. Gated by Config.cinematicVideoEnabled + isPro.
struct VideoView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var zoom = false

    private func close() {
        player?.pause()
        app.showVideo = false
        dismiss()
    }

    private let bars = 44

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let clip = app.renderedVideoURL {
                // Pro: the real AI-rendered clip, looping and muted, as backdrop.
                LoopingVideo(url: clip)
                    .ignoresSafeArea()
                LinearGradient(colors: [.clear, Brand.obsidian.opacity(0.7)],
                               startPoint: .center, endPoint: .bottom)
                    .ignoresSafeArea()
            } else {
                // Free visualizer: blurred cover with a slow push-in.
                Artwork(url: app.currentSong?.imageURL)
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(zoom ? 1.18 : 1.0)
                    .blur(radius: 26)
                    .opacity(0.55)
                    .clipped()
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: zoom)
                LinearGradient(colors: [.clear, Brand.obsidian.opacity(0.9)],
                               startPoint: .center, endPoint: .bottom)
                    .ignoresSafeArea()
            }

            VStack(spacing: 22) {
                HStack {
                    Button { close() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.down")
                            Text("Close")
                        }
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.35)))
                    }
                    Spacer()
                    Text("MUSIC VIDEO").font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white.opacity(0.7)).tracking(2)
                    Spacer()
                    if let url = app.renderedVideoURL ?? app.currentSong?.audioURL {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up").font(.title3).foregroundColor(.white) }
                    } else {
                        Image(systemName: "square.and.arrow.up").font(.title3).foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal).padding(.top, 8)

                Spacer()

                if app.renderedVideoURL == nil {
                    // Sharp centered cover with a soft pulse (visualizer only).
                    Artwork(url: app.currentSong?.imageURL)
                        .frame(width: 260, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: Brand.teal.opacity(0.5), radius: 30, y: 14)
                        .scaleEffect(zoom ? 1.03 : 0.99)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: zoom)
                }

                VStack(spacing: 6) {
                    Text(app.currentSong?.title ?? "Your Song")
                        .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(app.currentSong?.meta ?? "").foregroundColor(Brand.muted)
                }
                .padding(.horizontal)

                if app.renderedVideoURL == nil {
                    equalizer.frame(height: 70).padding(.horizontal, 24)
                }

                // Pro cinematic render entry point.
                if app.isRenderingVideo {
                    VStack(spacing: 8) {
                        ProgressView(value: app.videoProgress, total: 100).tint(Brand.emerald)
                        Text("Rendering cinematic video… \(Int(app.videoProgress))%")
                            .font(.system(size: 13)).foregroundColor(Brand.muted)
                    }
                    .padding(.horizontal, 40)
                } else if app.renderedVideoURL == nil {
                    Button { app.renderCinematicVideo() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                            Text("Cinematic video")
                            Text("PRO").font(.system(size: 11, weight: .heavy))
                                .foregroundColor(Brand.obsidian)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Brand.gradientGold).clipShape(Capsule())
                        }
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 30).fill(Brand.panel2)
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Brand.gold)))
                    }
                }

                Spacer()
            }
        }
        .onAppear { start() }
        .onDisappear { player?.pause() }
    }

    // Time-driven equalizer bars (visual rhythm, no audio tap needed).
    private var equalizer: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<bars, id: \.self) { i in
                    let phase = Double(i) * 0.5
                    let h = 0.25 + 0.75 * abs(sin(t * 3.0 + phase)) * (0.5 + 0.5 * abs(sin(t * 1.3 + phase * 0.7)))
                    Capsule()
                        .fill(Brand.gradient)
                        .frame(width: 4, height: max(6, CGFloat(h) * 70))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func start() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        zoom = true
        guard let url = app.currentSong?.audioURL else { return }
        let p = AVPlayer(url: url)
        player = p
        p.play()
    }
}

// A muted, looping AVPlayer layer used as the cinematic-clip backdrop.
struct LoopingVideo: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerLayerView {
        let v = PlayerLayerView()
        let item = AVPlayerItem(url: url)
        let p = AVQueuePlayer(playerItem: item)
        p.isMuted = true
        context.coordinator.looper = AVPlayerLooper(player: p, templateItem: item)
        v.playerLayer.player = p
        v.playerLayer.videoGravity = .resizeAspectFill
        p.play()
        return v
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var looper: AVPlayerLooper? }

    final class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
