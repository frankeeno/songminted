import SwiftUI

// Pro download: split the current song into separate instrument tracks and
// download each. 2-stem (vocals + instrumental) or full multi-stem split.
struct StemsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var loading = false
    @State private var status = ""
    @State private var errorText = ""
    @State private var stems: [(name: String, url: URL)] = []
    @State private var shareItem: ShareItem?
    @State private var downloading = ""
    @State private var zipping = false
    @State private var showMixer = false

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Stems").font(.system(size: 24, weight: .bold))
                    Text("PRO").font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.obsidian)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Brand.gradientGold).clipShape(Capsule())
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(Brand.muted)
                    }
                }
                Text("Download the separated instrument tracks for professional mixing.")
                    .font(.system(size: 14)).foregroundColor(Brand.muted)

                if stems.isEmpty && !loading {
                    choice("Vocals + Instrumental", "2 tracks · fast", "separate_vocal")
                    choice("Full split", "up to 12 tracks · drums, bass, guitar, keys…", "split_stem")
                }

                if loading {
                    HStack(spacing: 10) {
                        ProgressView().tint(Brand.emerald)
                        Text(status.isEmpty ? "Separating… this can take a minute" : status)
                            .font(.system(size: 14)).foregroundColor(Brand.muted)
                    }.padding(.top, 8)
                }
                if !errorText.isEmpty {
                    Text(errorText).font(.system(size: 13)).foregroundColor(.red)
                }

                if !stems.isEmpty {
                    HStack(spacing: 10) {
                        Button { openMixer() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "slider.horizontal.3")
                                Text("Mixer")
                                Text("PRO").font(.system(size: 9, weight: .heavy)).foregroundColor(Brand.obsidian)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Color.white.opacity(0.85)).clipShape(Capsule())
                            }
                            .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.obsidian)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Brand.gradientGold).clipShape(Capsule())
                        }
                        Button { downloadAllZip() } label: {
                            HStack(spacing: 6) {
                                if zipping { ProgressView().tint(.white) }
                                else { Image(systemName: "square.and.arrow.down.on.square") }
                                Text(zipping ? "Zipping…" : "Download all")
                            }
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 30).fill(Brand.panel2)
                                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Brand.emerald)))
                        }.disabled(zipping)
                    }
                    Text("\(stems.count) tracks · or tap one to save it on its own")
                        .font(.system(size: 12)).foregroundColor(Brand.muted)
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(stems, id: \.name) { st in stemRow(st) }
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
        .sheet(isPresented: $showMixer) { MixerView(stems: stems).environmentObject(app) }
    }

    private func choice(_ title: String, _ sub: String, _ type: String) -> some View {
        Button { run(type) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Text(sub).font(.system(size: 12)).foregroundColor(Brand.muted)
                }
                Spacer()
                Image(systemName: "scissors").foregroundColor(Brand.emerald)
            }
            .padding().background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.stroke)))
        }
    }

    private func stemRow(_ st: (name: String, url: URL)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform").foregroundColor(Brand.teal)
            Text(st.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Button { download(st) } label: {
                if downloading == st.name { ProgressView().tint(Brand.emerald) }
                else { Image(systemName: "square.and.arrow.down").foregroundColor(Brand.emerald) }
            }.disabled(downloading == st.name)
        }
        .padding().background(RoundedRectangle(cornerRadius: 14).fill(Brand.panel))
    }

    private func run(_ type: String) {
        guard Config.stemsEnabled else {
            errorText = "Stem separation is being switched on — it'll be live in the next update."
            return
        }
        guard let song = app.currentSong, let jid = song.jobId, let aid = song.providerAudioId else {
            errorText = "This track can't be split (it was made before stems were added). Mint a new song to use stems."
            return
        }
        loading = true; errorText = ""
        status = type == "split_stem" ? "Splitting into instruments…" : "Separating vocals…"
        Task {
            if Auth.shared.accessToken == nil { await Auth.shared.signInAnon() }
            guard let token = Auth.shared.accessToken else { loading = false; return }
            do {
                let svc = BackendSongService(accessToken: token)
                let r = try await svc.stems(jobId: jid, audioId: aid, type: type)
                stems = r; loading = false
                if r.isEmpty { errorText = "No stems came back — please try again." }
                await app.refreshCredits()
            } catch {
                loading = false; errorText = "Couldn't split: \(error.localizedDescription)"
            }
        }
    }

    private func download(_ st: (name: String, url: URL)) {
        downloading = st.name
        let title = (app.currentSong?.title ?? "Song").replacingOccurrences(of: "/", with: "-")
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: st.url)
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(title) - \(st.name).mp3")
                try data.write(to: dest)
                await MainActor.run { downloading = ""; shareItem = ShareItem(url: dest) }
            } catch {
                await MainActor.run { downloading = ""; errorText = "Download failed for \(st.name)." }
            }
        }
    }

    private func openMixer() {
        if app.isPro { showMixer = true }
        else { dismiss(); app.screen = .paywall }
    }

    // Download every stem into one folder, zip it, and share the single .zip.
    private func downloadAllZip() {
        guard !zipping else { return }
        zipping = true; errorText = ""
        let base = (app.currentSong?.title ?? "Song").replacingOccurrences(of: "/", with: "-")
        let all = stems
        Task {
            do {
                let dir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(base) Stems", isDirectory: true)
                try? FileManager.default.removeItem(at: dir)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                for st in all {
                    let (data, _) = try await URLSession.shared.data(from: st.url)
                    let safe = st.name.replacingOccurrences(of: "/", with: "-")
                    try data.write(to: dir.appendingPathComponent("\(safe).mp3"))
                }
                let zip = try zipFolder(dir)
                await MainActor.run { zipping = false; shareItem = ShareItem(url: zip) }
            } catch {
                await MainActor.run { zipping = false; errorText = "Couldn't prepare the zip." }
            }
        }
    }

    // Zip a folder using NSFileCoordinator's .forUploading (no third-party lib).
    private func zipFolder(_ folder: URL) throws -> URL {
        var out: URL?
        var coordErr: NSError?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: [.forUploading], error: &coordErr) { tmp in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(folder.lastPathComponent + ".zip")
            try? FileManager.default.removeItem(at: dest)
            do { try FileManager.default.copyItem(at: tmp, to: dest); out = dest } catch {}
        }
        if let e = coordErr { throw e }
        guard let z = out else { throw NSError(domain: "zip", code: 1) }
        return z
    }
}
