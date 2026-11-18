import SwiftUI

// MARK: - Explore (community feed)

struct ExploreView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            BrandHeader()
            VStack(alignment: .leading, spacing: 16) {
                Text("Explore").font(.system(size: 26, weight: .bold))

                ForEach(app.feed) { f in
                    Button {
                        app.play(Song(title: f.title, meta: "\(f.genre) · \(f.author)", badge: "◆ Community",
                                      audioURL: f.audioURL, imageURL: f.imageURL))
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            Artwork(url: f.imageURL)
                                .frame(height: 150).frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                                .frame(height: 150).frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.title).font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                                Text("\(f.author)   ▶ \(f.plays)   ♥ \(f.likes)")
                                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                            }
                            .padding()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Vault (your library)

struct VaultView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject private var rec = AudioRecorder.shared
    @ObservedObject private var pm = PlaybackManager.shared
    @State private var renaming: Song?
    @State private var newName = ""
    @State private var shareItem: ShareItem?

    var body: some View {
        ScrollView {
            BrandHeader()
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("vault_title")).font(.system(size: 26, weight: .bold)).padding(.bottom, 4)

                HStack(spacing: 10) {
                    filterChip("All", 0)
                    filterChip("Liked", 1)
                }.padding(.bottom, 4)

                Button { app.selectedTab = 0 } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .bold)).foregroundColor(Brand.obsidian)
                            .frame(width: 70, height: 70)
                            .background(Brand.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Text(tr("mint_a_song")).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                        Spacer()
                    }
                }

                ForEach(displayed) { s in
                    VStack(spacing: 8) {
                        // For covers: the user's original clip, shown first.
                        if let src = s.sourceAudioName { originalStrip(s, src) }
                        HStack(spacing: 14) {
                            Button { app.play(s) } label: { songRow(s) }
                            Button { app.toggleLike(s) } label: {
                                Image(systemName: s.liked ? "heart.fill" : "heart")
                                    .font(.title3).foregroundColor(s.liked ? Brand.emerald : Brand.muted)
                            }
                            Menu {
                                Button { newName = s.title; renaming = s } label: { Label("Rename", systemImage: "pencil") }
                                Button { download(s) } label: { Label("Download", systemImage: "square.and.arrow.down") }
                                if s.providerAudioId != nil {
                                    Button { app.currentSong = s; app.extendSong() } label: { Label("Extend", systemImage: "arrow.right.to.line") }
                                }
                                Button { app.coverFromLibrary(s) } label: { Label("Make a cover", systemImage: "mic") }
                                if s.sourceAudioName != nil {
                                    Button { app.reuseOriginal(s) } label: { Label("New version from original", systemImage: "arrow.triangle.2.circlepath") }
                                    Button(role: .destructive) { app.deleteOriginalAudio(s) } label: { Label("Delete original audio", systemImage: "waveform.slash") }
                                }
                                Button(role: .destructive) { app.deleteSong(s) } label: { Label("Delete song", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis").font(.title3).foregroundColor(Brand.muted)
                            }
                        }
                    }
                    .contextMenu {
                        Button { newName = s.title; renaming = s } label: { Label("Rename", systemImage: "pencil") }
                        Button(role: .destructive) { app.deleteSong(s) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .padding()
        }
        .alert("Rename track", isPresented: Binding(get: { renaming != nil },
                                                    set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $newName)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") { if let s = renaming { app.renameSong(s, to: newName) }; renaming = nil }
        }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
    }

    private func download(_ s: Song) {
        guard let url = s.audioURL else { app.showToast("No audio to download"); return }
        app.showToast("Downloading…")
        let title = s.title.replacingOccurrences(of: "/", with: "-")
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).mp3")
                try data.write(to: dest)
                await MainActor.run { shareItem = ShareItem(url: dest) }
            } catch {
                await MainActor.run { app.showToast("Download failed") }
            }
        }
    }

    @State private var filter = 0
    private var displayed: [Song] { filter == 0 ? app.library : app.library.filter { $0.liked } }

    // The user's original clip above a cover, so the Vault reads "original → generated".
    private func originalStrip(_ s: Song, _ src: String) -> some View {
        Button { rec.toggleSource(src) } label: {
            HStack(spacing: 12) {
                Image(systemName: rec.playingSource == src ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2).foregroundColor(Brand.gold)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("ORIGINAL").font(.system(size: 10, weight: .heavy)).foregroundColor(Brand.obsidian)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Brand.gold).clipShape(Capsule())
                        Text(s.sourceKind ?? "Your audio").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.gold)
                    }
                    Text("What you started from — tap to hear it")
                        .font(.system(size: 11)).foregroundColor(Brand.muted)
                }
                Spacer()
                Image(systemName: s.sourceKind == "Uploaded" ? "arrow.up.doc.fill" : "mic.fill")
                    .foregroundColor(Brand.muted)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Brand.gold.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.gold.opacity(0.35))))
        }
    }

    private func filterChip(_ label: String, _ v: Int) -> some View {
        Button { filter = v } label: {
            Text(label).font(.system(size: 14, weight: .semibold))
                .foregroundColor(filter == v ? Brand.obsidian : .white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(filter == v ? Brand.emerald : Brand.panel))
        }
    }

    private func songRow(_ s: Song) -> some View {
        let playing = pm.song?.id == s.id && pm.isPlaying
        return HStack(spacing: 12) {
            Artwork(url: s.imageURL)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title).font(.system(size: 15, weight: .semibold))
                    .foregroundColor(playing ? Brand.emerald : .white).lineLimit(1)
                Text(s.meta).font(.system(size: 12)).foregroundColor(Brand.muted).lineLimit(1)
            }
            Spacer()
            if playing { PlayingBars() }
        }
        .padding(.vertical, 4)
    }
}

// Tiny animated equalizer shown next to the currently-playing track.
struct PlayingBars: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let phase = Double(i) * 0.7
                    let h = 5 + 11 * abs(sin(t * 4 + phase))
                    Capsule().fill(Brand.emerald).frame(width: 3, height: CGFloat(h))
                }
            }
            .frame(width: 20, height: 16, alignment: .bottom)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var loc: Localizer
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = Auth.shared
    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            BrandBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Settings").font(.system(size: 26, weight: .bold))
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(Brand.muted)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Credits").font(.system(size: 13)).foregroundColor(Brand.muted)
                            Text("\(app.coins) ◉").font(.system(size: 22, weight: .bold)).foregroundColor(Brand.gold)
                        }
                        Spacer()
                        Button { dismiss(); app.screen = .paywall } label: {
                            Text("Go Pro").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.obsidian)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(Brand.gradientGold).clipShape(Capsule())
                        }
                    }
                    .padding().background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel))

                    // Account ID — tap to copy. Use it to grant credits in
                    // Supabase: update public.profiles set credits=1000 where id='<this>'.
                    Button {
                        UIPasteboard.general.string = auth.userId ?? ""
                        app.showToast("Account ID copied")
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Account ID").font(.system(size: 13)).foregroundColor(Brand.muted)
                                Text(auth.userId ?? "signing in…")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Image(systemName: "doc.on.doc").foregroundColor(Brand.emerald)
                        }
                        .padding().background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel))
                    }

                    Text("Language").font(.system(size: 18, weight: .bold))
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(appLanguages, id: \.code) { l in
                            Button { loc.set(l.code) } label: {
                                HStack(spacing: 10) {
                                    Text(l.flag).font(.system(size: 22))
                                    Text(l.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    Spacer()
                                    if loc.lang == l.code { Image(systemName: "checkmark.circle.fill").foregroundColor(Brand.emerald) }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Brand.panel)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(loc.lang == l.code ? Brand.emerald : Brand.stroke)))
                            }
                        }
                    }

                    Button { app.showToast("Purchases restored") } label: {
                        settingsRow("Restore purchases", "arrow.clockwise")
                    }
                    Button { app.showToast("Song Minted AI · v1.0") } label: {
                        settingsRow("About Song Minted", "info.circle")
                    }

                    Text("Song Minted AI · v1.0")
                        .font(.system(size: 12)).foregroundColor(Brand.muted)
                        .frame(maxWidth: .infinity).padding(.top, 8)
                }
                .padding()
            }
        }
    }

    private func settingsRow(_ t: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(Brand.emerald)
            Text(t).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(Brand.muted).font(.footnote)
        }
        .padding().background(RoundedRectangle(cornerRadius: 14).fill(Brand.panel))
    }
}
