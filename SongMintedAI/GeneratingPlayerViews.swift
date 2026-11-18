import SwiftUI
import AVFoundation

// MARK: - Generating overlay

struct GeneratingView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Brand.obsidian.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(Brand.gradientGold)
                    .rotationEffect(.degrees(app.progress * 3.6))
                    .animation(.easeInOut(duration: 0.2), value: app.progress)
                Text("\(Int(app.progress))%").font(.system(size: 50, weight: .bold))
                Text(label).foregroundColor(Brand.muted).font(.system(size: 18))
            }
        }
    }

    private var label: String {
        switch app.progress {
        case ..<25:  return "Writing lyrics…"
        case ..<50:  return "Composing melody…"
        case ..<75:  return "Adding vocals…"
        default:     return "Minting master…"
        }
    }
}

// MARK: - Player

struct PlayerView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject private var pm = PlaybackManager.shared
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var downloading = false
    @State private var shareItem: ShareItem?
    @State private var showStems = false
    @State private var showExtend = false

    var body: some View {
        ZStack {
            Brand.obsidian.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Button { app.showPlayer = false } label: {
                        Image(systemName: "chevron.down").font(.title2).foregroundColor(.white)
                    }
                    Spacer()
                    Menu {
                        if let s = app.currentSong {
                            Button { app.publish(s) } label: { Label(tr("publish_explore"), systemImage: "paperplane") }
                            if let url = s.audioURL { ShareLink(item: url) { Label(tr("share"), systemImage: "square.and.arrow.up") } }
                            Button { downloadSong() } label: { Label(tr("download"), systemImage: "square.and.arrow.down") }
                            Button(role: .destructive) { app.showPlayer = false; app.deleteSong(s) } label: { Label(tr("delete"), systemImage: "trash") }
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.title2).foregroundColor(.white)
                    }
                }
                .padding()

                Artwork(url: app.currentSong?.imageURL)
                    .frame(width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .overlay(alignment: .topTrailing) {
                        Text("◆ Minted")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Brand.gradientGold).clipShape(Capsule())
                            .padding(12)
                    }
                    .shadow(color: Brand.teal.opacity(0.4), radius: 24, y: 12)

                Text(app.currentSong?.title ?? tr("your_song")).font(.system(size: 26, weight: .bold))
                Text(app.currentSong?.meta ?? "").foregroundColor(Brand.muted)

                // Scrubber — drag to any point in the song.
                VStack(spacing: 4) {
                    Slider(value: Binding(get: { isScrubbing ? scrubTime : pm.currentTime },
                                          set: { scrubTime = $0 }),
                           in: 0...max(pm.duration, 0.1)) { editing in
                        isScrubbing = editing
                        if !editing { pm.seek(to: scrubTime) }
                    }
                    .tint(Brand.emerald)
                    .disabled(pm.duration <= 0)
                    HStack {
                        Text(timeString(isScrubbing ? scrubTime : pm.currentTime)).font(.system(size: 12)).foregroundColor(Brand.muted)
                        Spacer()
                        Text(timeString(pm.duration)).font(.system(size: 12)).foregroundColor(Brand.muted)
                    }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 40) {
                    Button { pm.skip(-15) } label: {
                        Image(systemName: "gobackward.15").font(.system(size: 26)).foregroundColor(.white)
                    }
                    Button { pm.toggle() } label: {
                        Image(systemName: pm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30)).foregroundColor(Brand.obsidian)
                            .frame(width: 78, height: 78)
                            .background(Brand.gradient).clipShape(Circle())
                    }
                    Button { pm.skip(15) } label: {
                        Image(systemName: "goforward.15").font(.system(size: 26)).foregroundColor(.white)
                    }
                }
                .padding(.top, 6)

                HStack(spacing: 14) {
                    Button { downloadSong() } label: {
                        actionLabel(downloading ? tr("downloading") : tr("download"),
                                    downloading ? "arrow.down.circle" : "square.and.arrow.down")
                    }.disabled(downloading || app.currentSong?.audioURL == nil)
                    Button { if let s = app.currentSong { app.publish(s) } } label: { actionLabel(tr("publish"), "paperplane") }
                }

                Button { showExtend = true } label: {
                    Label(tr("extend"), systemImage: "arrow.right.to.line")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 30).fill(Brand.panel2)
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Brand.teal)))
                }
                .disabled(app.currentSong?.providerAudioId == nil)
                .padding(.horizontal, 24)

                Button { showStems = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "scissors")
                        Text(tr("download_stems"))
                        Text("PRO").font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.obsidian)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Brand.gradientGold).clipShape(Capsule())
                    }
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 30).fill(Brand.panel2)
                        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Brand.gold)))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear { if let s = app.currentSong { pm.load(s) } }
        .onChange(of: app.currentSong) { _, s in if let s, s.id != pm.song?.id { pm.load(s, restart: true) } }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
        .sheet(isPresented: $showStems) { StemsView().environmentObject(app) }
        .sheet(isPresented: $showExtend) { ExtendSheet(duration: pm.duration).environmentObject(app) }
    }

    private func timeString(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let t = Int(s)
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    // Real download: pull the mp3 to a local file, then offer Save to Files / share.
    private func downloadSong() {
        guard let url = app.currentSong?.audioURL else { return }
        downloading = true
        let title = (app.currentSong?.title ?? "Song").replacingOccurrences(of: "/", with: "-")
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).mp3")
                try data.write(to: dest)
                await MainActor.run { downloading = false; shareItem = ShareItem(url: dest) }
            } catch {
                await MainActor.run { downloading = false; app.showToast("Download failed") }
            }
        }
    }

    private func actionLabel(_ t: String, _ icon: String) -> some View {
        Label(t, systemImage: icon)
            .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 30).fill(Brand.panel2)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Brand.stroke)))
    }
}

// Wraps a downloaded file so the iOS share sheet can offer "Save to Files".
struct ShareItem: Identifiable { let id = UUID(); let url: URL }

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// Controls for Extend: choose where to continue from and where the song goes next.
struct ExtendSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let duration: Double
    @State private var fromEnd = true
    @State private var continueAt: Double = 0
    @State private var direction = ""

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(tr("extend_song")).font(.system(size: 24, weight: .bold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(Brand.muted)
                    }
                }
                Text(tr("extend_sub"))
                    .font(.system(size: 14)).foregroundColor(Brand.muted)

                Toggle(isOn: $fromEnd) {
                    Text(tr("continue_from_end")).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                }.tint(Brand.emerald)

                if !fromEnd && duration > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(tr("continue_from")) \(Int(continueAt) / 60):\(String(format: "%02d", Int(continueAt) % 60))")
                            .font(.system(size: 13)).foregroundColor(Brand.emerald)
                        Slider(value: $continueAt, in: 0...max(1, duration - 1)).tint(Brand.emerald)
                    }
                }

                Text(tr("where_next")).font(.system(size: 12, weight: .bold)).foregroundColor(Brand.muted)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.stroke))
                    TextEditor(text: $direction).frame(minHeight: 110).padding(8)
                        .scrollContentBackground(.hidden).background(Color.clear)
                    if direction.isEmpty {
                        Text(tr("where_next_ph"))
                            .foregroundColor(Brand.muted).padding(14).allowsHitTesting(false)
                    }
                }

                Button {
                    let at: Double? = (!direction.isEmpty) ? (fromEnd ? max(1, duration - 1) : continueAt) : nil
                    dismiss(); app.showPlayer = false
                    app.extendSong(prompt: direction, continueAt: at)
                } label: {
                    Label(tr("extend"), systemImage: "arrow.right.to.line")
                        .font(.system(size: 17, weight: .bold)).foregroundColor(Brand.obsidian)
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Brand.gradient).clipShape(Capsule())
                }
                Spacer()
            }
            .padding()
        }
    }
}
