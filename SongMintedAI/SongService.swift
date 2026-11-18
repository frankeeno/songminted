import Foundation

// MARK: - Provider-agnostic song service
//
// The app never talks to an AI provider directly. It talks to ONE interface.
// Your backend chooses which engine runs (EvoLink / Mureka / ElevenLabs) based
// on the user's tier. See SongMinted-AI-Services-Spec for the full architecture.

protocol SongService {
    /// Kicks off generation and reports progress 0–100. Returns a playable URL.
    func generate(prompt: String,
                  style: String,
                  instrumental: Bool,
                  progress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

// MARK: - Real integration (Phase 1) — talks to YOUR backend, not EvoLink directly.
//
//  final class BackendSongService: SongService {
//      let base = URL(string: "https://api.songminted.com")!
//      func generate(prompt: String, style: String, instrumental: Bool,
//                    progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
//          // 1. POST /mint  { prompt, style, instrumental }  -> jobId
//          // 2. poll GET /job/{jobId} every ~2s, call progress(pct)
//          // 3. when status == "completed", return the signed audio URL
//      }
//  }
//
// The backend deducts a credit, calls the chosen provider with the server-side
// API key, stores the finished audio in R2/S3, and hands back a download URL.
