import SwiftUI

// MARK: - Data models

struct Song: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var meta: String
    var badge: String
    var gradient: Bool = false
    var audioURL: URL? = nil
    var imageURL: URL? = nil
    var liked: Bool = false
    var providerAudioId: String? = nil   // Suno track id, needed to Extend
    var jobId: String? = nil             // our backend job id, resolves to the Suno task for Stems
    var sourceAudioName: String? = nil   // the user's original clip a cover was built from
    var sourceKind: String? = nil        // "Uploaded" or "Hummed" — how the original was captured
}

struct FeedItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var genre: String
    var author: String
    var plays: String
    var likes: String
    var imageURL: URL? = nil
    var audioURL: URL? = nil
}

enum AppScreen { case language, onboarding, paywall, main }

enum StudioSheet: Int, Identifiable { case genre, mood, voice; var id: Int { rawValue } }

let genreOptions: [(String, String)] = [
    ("🎵","Pop"),("💃","Dance-Pop"),("🌆","Synth-Pop"),("🇰🇷","K-Pop"),("✨","Hyperpop"),
    ("🎧","Hip-Hop"),("🔥","Trap"),("📻","Boom Bap"),("🕳️","Drill"),("😈","Phonk"),
    ("🎤","R&B"),("🌙","Neo-Soul"),("💜","Soul"),("🕺","Funk"),("🪩","Disco"),
    ("🎸","Rock"),("🤘","Metal"),("💥","Punk"),("🌫️","Alt Rock"),("🎩","Classic Rock"),
    ("🦋","Indie"),("🍂","Indie Folk"),("🎻","Folk"),("🌾","Americana"),("🪕","Bluegrass"),
    ("🤠","Country"),("🚜","Country Pop"),
    ("🎛️","EDM"),("🏠","House"),("🌊","Deep House"),("⚙️","Techno"),("🌀","Trance"),
    ("🔊","Dubstep"),("🥁","Drum & Bass"),("👾","Synthwave"),
    ("🎹","Lo-Fi"),("☕","Chillhop"),("🌌","Ambient"),("🧘","Meditation"),
    ("🎺","Jazz"),("🎷","Smooth Jazz"),("🎩","Swing"),("🎼","Blues"),
    ("🥁","Afrobeat"),("🍹","Amapiano"),("🌴","Reggae"),("🔈","Reggaeton"),
    ("💐","Latin"),("💃🏽","Salsa"),("🇧🇷","Bossa Nova"),("🌍","World"),
    ("⛪","Gospel"),("🎬","Cinematic"),("🎻","Orchestral"),("🎭","Musical Theatre"),
    ("🎄","Holiday"),("🧸","Kids")
]
let moodOptions: [(String, String)] = [("⚡","Energetic"),("😊","Happy"),("💖","Romantic"),("🔥","Aggressive"),("😢","Sad"),("🌟","Uplifting"),("❄️","Chill"),("🧘","Relaxing"),("😔","Melancholic"),("😂","Fun"),("🛸","Futuristic"),("🌙","Dreamy")]
let voiceOptions: [(String, String)] = [("🎲","Random"),("👱‍♂️","Male"),("👩‍🦰","Female"),("🌟","Nova"),("🔥","Blaze"),("🌊","Echo"),("🏙️","Ryder"),("🌙","Luna"),("🖤","Onyx")]
let tempoOptions = ["Slow","Medium","Fast","Very Fast"]

// MARK: - App state (single source of truth)

@MainActor
final class AppState: ObservableObject {
    @Published var screen: AppScreen = Localizer.shared.hasChosen ? .onboarding : .language
    @Published var selectedTab: Int = 0
    @Published var coins: Int = 3

    // Studio inputs
    @Published var mode: Int = 0        // 0 Simple · 1 Custom · 2 Photo
    @Published var prompt: String = ""
    @Published var titleText: String = ""
    @Published var lyrics: String = ""          // exact lyrics (Custom mode) — editable
    @Published var writingLyrics = false        // spinner while AI writes lyrics
    @Published var instrumental: Bool = false
    @Published var genre: String = ""
    @Published var mood: String = ""
    @Published var voice: String = ""
    @Published var tempo: String = ""
    // Personalization sliders (0–1), same three knobs Suno exposes.
    @Published var audioWeight: Double = 0.70   // how faithfully a cover follows YOUR audio
    @Published var styleWeight: Double = 0.60   // how strongly it sticks to the chosen style
    @Published var weirdness: Double = 0.30     // how experimental / weird it gets
    @Published var activeSheet: StudioSheet? = nil
    @Published var toast: String? = nil
    @Published var showSettings = false
    @Published var photoURL: URL? = nil      // photo chosen in Photo mode (becomes cover art)
    @Published var showVideo = false          // music-video visualizer
    @Published var isPro = UserDefaults.standard.bool(forKey: "is_pro") { didSet {
        UserDefaults.standard.set(isPro, forKey: "is_pro") } }
    @Published var hasClonedVoice = false

    // Cinematic video (Higgsfield) render state
    @Published var isRenderingVideo = false
    @Published var videoProgress: Double = 0
    @Published var renderedVideoURL: URL? = nil

    // Generation + player
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var currentSong: Song?
    @Published var showPlayer = false
    @Published var isPlaying = false

    @Published var library: [Song] = [
        Song(title: "You Smiled First", meta: "Pop 🎵 · Happy 😊", badge: "Sample Song",
             imageURL: URL(string: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&q=80")),
        Song(title: "Chloe in the Morning Light", meta: "Indie 🦋 · Romantic 💖", badge: "Sample Song",
             imageURL: URL(string: "https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400&q=80")),
        Song(title: "Little Leo's Laughter", meta: "Folk 🎻 · Uplifting 🌟", badge: "Sample Cover",
             imageURL: URL(string: "https://images.unsplash.com/photo-1490725263030-1f0521cec8ee?w=400&q=80"))
    ] { didSet { saveLibrary() } }

    @Published var feed: [FeedItem] = [
        FeedItem(title: "Neon Overdrive", genre: "EDM", author: "@synthlord", plays: "128K", likes: "9.2K",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=600&q=80"),
                 audioURL: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")),
        FeedItem(title: "Sunday in Lisbon", genre: "Lo-Fi", author: "@mellowbeats", plays: "87K", likes: "6.4K",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=600&q=80"),
                 audioURL: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3")),
        FeedItem(title: "Concrete Kings", genre: "Hip-Hop", author: "@b4rs", plays: "204K", likes: "15K",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80"),
                 audioURL: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3")),
        FeedItem(title: "Paper Hearts", genre: "Pop", author: "@ava.m", plays: "62K", likes: "4.1K",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=600&q=80"),
                 audioURL: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3"))
    ]

    init() {
        loadLibrary()
        Task { await Auth.shared.signInAnon(); await refreshCredits() }
    }

    /// Pull the REAL credit balance + Pro flag from the backend (profiles table,
    /// RLS-scoped to this user) and show them. The backend is the source of
    /// truth — the app no longer guesses with a local counter.
    func refreshCredits() async {
        guard let token = Auth.shared.accessToken,
              var comps = URLComponents(string: Config.supabaseURL + "/rest/v1/profiles") else { return }
        comps.queryItems = [URLQueryItem(name: "select", value: "credits,is_pro,voice_id")]
        guard let url = comps.url else { return }
        var req = URLRequest(url: url)
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let row = arr.first {
                if let c = row["credits"] as? Int { coins = c }
                if let p = row["is_pro"] as? Bool { isPro = p }
                hasClonedVoice = (row["voice_id"] as? String)?.isEmpty == false
            }
        } catch { print("refreshCredits error:", error) }
    }

    /// Mint a song. Real backend when Config.useRealBackend, else a mock progress loop.
    func mintSong() {
        let g = genre.isEmpty ? "Pop" : genre
        let m = mood.isEmpty ? "Happy" : mood
        let title = titleText.isEmpty ? SongTitles.random() : titleText
        var song = Song(title: title, meta: "\(g) · \(m)", badge: "◆ Minted", gradient: Bool.random())

        currentSong = song
        renderedVideoURL = nil
        isGenerating = true
        progress = 0

        guard Config.useRealBackend else { runMock(song); return }

        // Progress reflects the real provider stages (≈15 queued, 40 lyrics,
        // 70 first track), with a gentle creep that only fills the gap toward
        // the next stage — so it never races ahead and freezes at 90.
        var lastBackend = 10.0
        let creep = Task { @MainActor in
            while isGenerating {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                let ceiling = min(93.0, lastBackend + 12.0)
                if progress < ceiling { progress = min(ceiling, progress + Double.random(in: 0.4...1.6)) }
            }
        }

        Task {
            if Auth.shared.accessToken == nil { await Auth.shared.signInAnon() }
            guard let token = Auth.shared.accessToken else { creep.cancel(); runMock(song); return }
            do {
                let svc = BackendSongService(accessToken: token)
                let promptText = prompt.isEmpty ? "\(m) \(g) song" : prompt
                let audio = AudioRecorder.shared.hasClip ? AudioRecorder.shared.base64Clip() : nil
                // Custom mode with edited/written lyrics → sing exact words.
                let lyricsToUse = (mode == 1 && !instrumental) ? lyrics : ""
                let jobId = try await svc.startMint(prompt: promptText, genre: g, mood: m,
                                                    tempo: tempo, voice: voice, title: title,
                                                    instrumental: instrumental, audioBase64: audio,
                                                    lyrics: lyricsToUse,
                                                    audioWeight: audioWeight, styleWeight: styleWeight,
                                                    weirdness: weirdness)
                var results: [(title: String, audio: URL, image: URL?, audioId: String?, taskId: String?)] = []
                let deadline = Date().addingTimeInterval(300)   // hard 5-min timeout (covers run long)
                while true {
                    try await Task.sleep(nanoseconds: 2_500_000_000)
                    let r = try await svc.poll(jobId)
                    lastBackend = max(lastBackend, r.progress)
                    if r.progress > progress { progress = min(95, r.progress) }
                    if r.status == "completed", !r.songs.isEmpty { results = r.songs; break }
                    if r.status == "failed" { creep.cancel(); isGenerating = false; showToast("Generation failed — please try again"); return }
                    if Date() > deadline { creep.cancel(); isGenerating = false; showToast("Still rendering — check your Vault shortly"); return }
                }
                creep.cancel()
                progress = 100
                // For covers, keep the user's original clip for provenance.
                let srcName = (audio != nil) ? AudioRecorder.shared.persistSource() : nil
                let srcKind = (audio != nil) ? AudioRecorder.shared.sourceKind : nil
                // Insert every version the model returned (Suno makes 2 per song).
                var firstSong: Song? = nil
                for (i, v) in results.enumerated() {
                    var s = song
                    s.id = UUID()
                    s.title = v.title.isEmpty ? song.title : v.title
                    s.audioURL = v.audio
                    // Photo mode: keep the user's photo as the cover art.
                    s.imageURL = (mode == 2 && photoURL != nil) ? photoURL : v.image
                    s.providerAudioId = v.audioId
                    s.jobId = jobId
                    s.sourceAudioName = srcName
                    s.sourceKind = srcKind
                    s.badge = results.count > 1 ? (srcName != nil ? "◆ Cover · v\(i + 1)" : "◆ Minted · v\(i + 1)") : (srcName != nil ? "◆ Cover" : "◆ Minted")
                    library.insert(s, at: 0)
                    if firstSong == nil { firstSong = s }
                }
                if let f = firstSong { currentSong = f }
                await refreshCredits()
                AudioRecorder.shared.reset()
                isGenerating = false; isPlaying = true; showPlayer = true
            } catch {
                print("mint error:", error)
                creep.cancel()
                isGenerating = false
                showToast("Couldn't start: \(error.localizedDescription)")
            }
        }
    }

    private func runMock(_ song: Song) {
        Task {
            while progress < 100 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                progress = min(100, progress + Double.random(in: 2...9))
            }
            if coins > 0 { coins -= 1 }
            library.insert(song, at: 0)
            isGenerating = false; isPlaying = true; showPlayer = true
        }
    }

    func play(_ song: Song) {
        currentSong = song
        renderedVideoURL = nil
        isPlaying = true
        showPlayer = true
    }

    /// Render a cinematic clip for the current song via Higgsfield (Pro-only).
    func renderCinematicVideo() {
        guard Config.cinematicVideoEnabled else {
            showToast("Cinematic video — coming soon"); return
        }
        guard isPro else { showVideo = false; screen = .paywall; return }
        guard let song = currentSong else { return }

        renderedVideoURL = nil
        isRenderingVideo = true
        videoProgress = 0

        Task {
            if Auth.shared.accessToken == nil { await Auth.shared.signInAnon() }
            guard let token = Auth.shared.accessToken else { isRenderingVideo = false; return }
            do {
                let svc = BackendVideoService(accessToken: token)
                let prompt = "cinematic music video, \(song.meta), slow push-in, dramatic lighting, film grain"
                let jobId = try await svc.start(prompt: prompt, imageURL: song.imageURL)
                while true {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    let r = try await svc.poll(jobId)
                    videoProgress = max(videoProgress, min(99, r.progress))
                    if r.status == "completed", let v = r.video { renderedVideoURL = v; break }
                    if r.status == "failed" { isRenderingVideo = false; showToast("Video render failed"); return }
                }
                videoProgress = 100
                isRenderingVideo = false
            } catch {
                print("video error:", error)
                isRenderingVideo = false
                showToast("Video render failed")
            }
        }
    }

    /// Continue/lengthen the current song via Suno's extend. Result lands in the Vault.
    /// Optional controls: where to continue from, a new prompt/lyrics, and style.
    func extendSong(prompt: String = "", style: String = "", continueAt: Double? = nil) {
        guard let base = currentSong else { return }
        guard let audioId = base.providerAudioId, !audioId.isEmpty else {
            showToast("This track can't be extended (older song)"); return
        }
        currentSong = base
        renderedVideoURL = nil
        isGenerating = true
        progress = 0
        var lastBackend = 10.0
        let creep = Task { @MainActor in
            while isGenerating {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                let ceiling = min(93.0, lastBackend + 12.0)
                if progress < ceiling { progress = min(ceiling, progress + Double.random(in: 0.4...1.6)) }
            }
        }
        Task {
            if Auth.shared.accessToken == nil { await Auth.shared.signInAnon() }
            guard let token = Auth.shared.accessToken else { creep.cancel(); isGenerating = false; return }
            do {
                let svc = BackendSongService(accessToken: token)
                let jobId = try await svc.startExtend(audioId: audioId, prompt: prompt,
                                                      style: style, title: base.title,
                                                      continueAt: continueAt)
                var results: [(title: String, audio: URL, image: URL?, audioId: String?, taskId: String?)] = []
                let deadline = Date().addingTimeInterval(300)
                while true {
                    try await Task.sleep(nanoseconds: 2_500_000_000)
                    let r = try await svc.poll(jobId)
                    lastBackend = max(lastBackend, r.progress)
                    if r.progress > progress { progress = min(95, r.progress) }
                    if r.status == "completed", !r.songs.isEmpty { results = r.songs; break }
                    if r.status == "failed" { creep.cancel(); isGenerating = false; showToast("Extend failed — please try again"); return }
                    if Date() > deadline { creep.cancel(); isGenerating = false; showToast("Still rendering — check your Vault shortly"); return }
                }
                creep.cancel(); progress = 100
                var first: Song? = nil
                for (i, v) in results.enumerated() {
                    var s = base
                    s.id = UUID()
                    s.title = (v.title.isEmpty ? base.title : v.title) + " (Extended)"
                    s.audioURL = v.audio
                    s.imageURL = v.image ?? base.imageURL
                    s.providerAudioId = v.audioId
                    s.jobId = jobId
                    s.badge = results.count > 1 ? "◆ Extended · v\(i + 1)" : "◆ Extended"
                    library.insert(s, at: 0)
                    if first == nil { first = s }
                }
                if let f = first { currentSong = f }
                await refreshCredits()
                isGenerating = false; isPlaying = true; showPlayer = true
            } catch {
                creep.cancel(); isGenerating = false
                showToast("Couldn't extend: \(error.localizedDescription)")
            }
        }
    }

    /// Ask the AI to write lyrics from the current idea; fills the editable box.
    func writeLyrics() {
        guard !writingLyrics else { return }
        let idea = prompt.isEmpty ? "\(mood) \(genre) song".trimmingCharacters(in: .whitespaces) : prompt
        writingLyrics = true
        Task {
            if Auth.shared.accessToken == nil { await Auth.shared.signInAnon() }
            guard let token = Auth.shared.accessToken else { writingLyrics = false; return }
            do {
                let svc = BackendSongService(accessToken: token)
                let r = try await svc.generateLyrics(idea: idea.isEmpty ? "an uplifting pop song" : idea)
                lyrics = r.text
                if titleText.isEmpty, !r.title.isEmpty { titleText = r.title }
                writingLyrics = false
                showToast("Lyrics ready — edit as you like")
            } catch {
                writingLyrics = false
                showToast("Couldn't write lyrics: \(error.localizedDescription)")
            }
        }
    }

    func showToast(_ s: String) {
        toast = s
        Task {
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            if toast == s { toast = nil }
        }
    }

    func publish(_ song: Song) {
        feed.insert(FeedItem(title: song.title,
                             genre: genre.isEmpty ? "Pop" : genre,
                             author: "@you", plays: "0", likes: "0",
                             imageURL: song.imageURL, audioURL: song.audioURL), at: 0)
        showToast("Published to Explore 🚀")
    }

    func applyTemplate(genre g: String, mood m: String, prompt p: String, instrumental inst: Bool = false) {
        genre = g; mood = m; prompt = p; instrumental = inst
        selectedTab = 0
        showToast("Template ready — tap Mint")
    }

    func toggleLike(_ song: Song) {
        if let i = library.firstIndex(where: { $0.id == song.id }) {
            library[i].liked.toggle()
        }
    }

    /// Rename a track. Updates the Library (and the now-playing song if it's this one).
    func renameSong(_ song: Song, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = library.firstIndex(where: { $0.id == song.id }) else { return }
        library[i].title = t
        if currentSong?.id == song.id { currentSong?.title = t }
        if PlaybackManager.shared.song?.id == song.id { PlaybackManager.shared.song?.title = t }
        showToast("Renamed")
    }

    func deleteSong(_ song: Song) {
        library.removeAll { $0.id == song.id }
        if currentSong?.id == song.id { currentSong = nil }
        showToast("Deleted")
    }

    /// Remove just the saved original clip from a cover (keeps the song).
    func deleteOriginalAudio(_ song: Song) {
        guard let i = library.firstIndex(where: { $0.id == song.id }) else { return }
        if let name = library[i].sourceAudioName {
            try? FileManager.default.removeItem(at: AudioRecorder.sourceURL(name))
        }
        library[i].sourceAudioName = nil
        library[i].sourceKind = nil
        showToast("Original audio removed")
    }

    /// Use a library song's audio as the source for a new cover, then open Cover.
    func coverFromLibrary(_ song: Song) {
        guard let url = song.audioURL else { showToast("No audio to cover"); return }
        showToast("Loading track…")
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("coversrc-\(UUID().uuidString).mp3")
                try? data.write(to: dest)
                AudioRecorder.shared.useUploadedFile(dest)
                AudioRecorder.shared.sourceKind = "From a song"
                selectedTab = 1   // Cover tab
                showToast("Ready — pick a voice & style, then Mint Cover")
            } else {
                showToast("Couldn't load that track")
            }
        }
    }

    /// Load a cover's saved original clip back into the input so the user can
    /// mint a fresh version (or extension) from it. Opens the Studio tab.
    func reuseOriginal(_ song: Song) {
        guard let name = song.sourceAudioName else { showToast("No original audio saved"); return }
        let url = AudioRecorder.sourceURL(name)
        guard FileManager.default.fileExists(atPath: url.path) else { showToast("Original audio not found"); return }
        AudioRecorder.shared.useUploadedFile(url)
        AudioRecorder.shared.sourceKind = song.sourceKind ?? "Uploaded"
        selectedTab = 0
        showToast("Loaded your original — tweak the style and Mint again")
    }

    private func saveLibrary() {
        if let data = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(data, forKey: "library_v1")
        }
    }

    private func loadLibrary() {
        if let data = UserDefaults.standard.data(forKey: "library_v1"),
           let songs = try? JSONDecoder().decode([Song].self, from: data) {
            library = songs
        }
    }
}

enum SongTitles {
    static let a = ["Golden", "Midnight", "Neon", "Velvet", "Electric", "Minted"]
    static let b = ["Hour", "Dreams", "Heartbeat", "Horizon", "Echoes", "Sunrise"]
    static func random() -> String { "\(a.randomElement()!) \(b.randomElement()!)" }
}
