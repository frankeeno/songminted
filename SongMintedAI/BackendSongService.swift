import Foundation

// Talks to the Supabase edge functions (which call EvoLink). Plain URLSession.
struct BackendSongService {
    let accessToken: String
    private var base: String { Config.supabaseURL + "/functions/v1" }

    // A session that can't hang forever — surfaces a timeout instead.
    private var session: URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }

    private func authHeaders(_ req: inout URLRequest) {
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    // Kicks off generation, returns a jobId. Honors genre/mood/tempo/voice.
    // When audioBase64 is present, the backend builds a COVER from the clip.
    // Ask the AI to write lyrics from an idea. Returns (lyrics, suggested title).
    func generateLyrics(idea: String) async throws -> (text: String, title: String) {
        var req = URLRequest(url: URL(string: base + "/mint")!)
        req.httpMethod = "POST"
        authHeaders(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: ["action": "lyrics", "prompt": idea])
        let (data, _) = try await session.data(for: req)
        let obj = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        if let text = obj["lyrics"] as? String { return (text, (obj["title"] as? String) ?? "") }
        throw NSError(domain: "lyrics", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: (obj["error"] as? String) ?? "lyrics failed"])
    }

    func startMint(prompt: String, genre: String, mood: String, tempo: String,
                   voice: String, title: String, instrumental: Bool,
                   audioBase64: String? = nil, lyrics: String = "",
                   audioWeight: Double = 0.7, styleWeight: Double = 0.6,
                   weirdness: Double = 0.3) async throws -> String {
        var req = URLRequest(url: URL(string: base + "/mint")!)
        req.httpMethod = "POST"
        authHeaders(&req)
        var body: [String: Any] = [
            "prompt": prompt, "style": genre, "mood": mood, "tempo": tempo,
            "voice": voice, "title": title, "instrumental": instrumental,
            "kind": audioBase64 == nil ? "song" : "cover",
            "audioWeight": audioWeight, "styleWeight": styleWeight, "weirdness": weirdness
        ]
        if !lyrics.isEmpty { body["lyrics"] = lyrics }
        if let a = audioBase64 { body["audioBase64"] = a }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let jobId = obj["jobId"] as? String { return jobId }
            let msg = (obj["error"] as? String) ?? (obj["detail"] as? String) ?? "mint failed"
            throw NSError(domain: "mint", code: (resp as? HTTPURLResponse)?.statusCode ?? 1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        throw NSError(domain: "mint", code: 1, userInfo: [NSLocalizedDescriptionKey: "mint failed"])
    }

    // Polls status; returns (status, progress 0-100, versions when ready).
    func poll(_ jobId: String) async throws -> (status: String, progress: Double, songs: [(title: String, audio: URL, image: URL?, audioId: String?, taskId: String?)]) {
        var comps = URLComponents(string: base + "/job-status")!
        comps.queryItems = [URLQueryItem(name: "jobId", value: jobId)]
        var req = URLRequest(url: comps.url!)
        authHeaders(&req)
        let (data, _) = try await session.data(for: req)
        let obj = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        // Surface backend errors instead of spinning forever at 0%.
        if obj["status"] == nil, let err = obj["error"] as? String {
            throw NSError(domain: "job-status", code: 1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        let status = (obj["status"] as? String) ?? "generating"
        let progress = (obj["progress"] as? Double) ?? Double((obj["progress"] as? Int) ?? 0)

        let taskId = obj["taskId"] as? String
        var songs: [(title: String, audio: URL, image: URL?, audioId: String?, taskId: String?)] = []
        if let arr = obj["versions"] as? [[String: Any]] {
            for v in arr {
                if let a = (v["audioUrl"] as? String).flatMap({ URL(string: $0) }) {
                    songs.append(((v["title"] as? String) ?? "Untitled", a,
                                  (v["imageUrl"] as? String).flatMap { URL(string: $0) },
                                  v["audioId"] as? String, (v["taskId"] as? String) ?? taskId))
                }
            }
        } else if let a = (obj["audioUrl"] as? String).flatMap({ URL(string: $0) }) {
            songs.append(((obj["title"] as? String) ?? "Untitled", a,
                          (obj["imageUrl"] as? String).flatMap { URL(string: $0) }, nil, taskId))
        }
        return (status, progress, songs)
    }

    // Separate a track into stems. type: "separate_vocal" (vocals+instrumental)
    // or "split_stem" (up to 12). Returns [(name, downloadURL)]. Runs to completion.
    func stems(jobId: String, audioId: String, type: String) async throws -> [(name: String, url: URL)] {
        var req = URLRequest(url: URL(string: base + "/stems")!)
        req.httpMethod = "POST"
        authHeaders(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: ["jobId": jobId, "audioId": audioId, "type": type])
        // Stems separation can take a couple of minutes.
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 180; cfg.timeoutIntervalForResource = 200
        let (data, _) = try await URLSession(configuration: cfg).data(for: req)
        let obj = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        if let arr = obj["stems"] as? [[String: Any]] {
            return arr.compactMap { s in
                guard let n = s["name"] as? String, let u = (s["url"] as? String).flatMap({ URL(string: $0) }) else { return nil }
                return (n, u)
            }
        }
        throw NSError(domain: "stems", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: (obj["error"] as? String) ?? "stems failed"])
    }

    // Continue/lengthen an existing track. Returns a jobId (poll like a mint).
    // Optional controls: continueAt (seconds), a new prompt/lyrics, and style.
    func startExtend(audioId: String, prompt: String = "", style: String = "",
                     title: String = "", continueAt: Double? = nil) async throws -> String {
        var req = URLRequest(url: URL(string: base + "/extend")!)
        req.httpMethod = "POST"
        authHeaders(&req)
        var body: [String: Any] = ["audioId": audioId]
        if !prompt.isEmpty { body["prompt"] = prompt }
        if !style.isEmpty { body["style"] = style }
        if !title.isEmpty { body["title"] = title }
        if let c = continueAt { body["continueAt"] = c }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        let obj = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        if let jobId = obj["jobId"] as? String { return jobId }
        let msg = (obj["error"] as? String) ?? "extend failed"
        throw NSError(domain: "extend", code: (resp as? HTTPURLResponse)?.statusCode ?? 1,
                      userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
