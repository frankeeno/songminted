import Foundation

// Talks to the /video edge function (which calls Higgsfield). Pro-only.
struct BackendVideoService {
    let accessToken: String
    private var base: String { Config.supabaseURL + "/functions/v1" }

    private func headers(_ req: inout URLRequest) {
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    // Start a cinematic render, returns a jobId.
    func start(prompt: String, imageURL: URL?, motion: String = "push_in") async throws -> String {
        var req = URLRequest(url: URL(string: base + "/video")!)
        req.httpMethod = "POST"
        headers(&req)
        var body: [String: Any] = ["prompt": prompt, "motion": motion]
        if let u = imageURL { body["imageUrl"] = u.absoluteString }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let obj = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        if let jobId = obj["jobId"] as? String { return jobId }
        throw NSError(domain: "video", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: (obj["error"] as? String) ?? "video start failed"])
    }

    // Poll status; returns (status, progress 0-100, video url when ready).
    func poll(_ jobId: String) async throws -> (status: String, progress: Double, video: URL?) {
        var comps = URLComponents(string: base + "/video")!
        comps.queryItems = [URLQueryItem(name: "jobId", value: jobId)]
        var req = URLRequest(url: comps.url!)
        headers(&req)
        let (data, _) = try await URLSession.shared.data(for: req)
        let obj = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        let status = (obj["status"] as? String) ?? "generating"
        let progress = (obj["progress"] as? Double) ?? Double((obj["progress"] as? Int) ?? 0)
        let video = (obj["videoUrl"] as? String).flatMap { URL(string: $0) }
        return (status, progress, video)
    }
}
