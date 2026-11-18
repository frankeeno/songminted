import Foundation

// Persistent anonymous Supabase auth. ONE account per install: the session
// (access + refresh token) is saved and refreshed on launch, instead of
// creating a brand-new anonymous user every time — which is what used to
// strand the user's credits on throwaway accounts.
@MainActor
final class Auth: ObservableObject {
    static let shared = Auth()
    @Published var accessToken: String?
    @Published var userId: String?

    private let tokenKey   = "sb_access_token"
    private let refreshKey = "sb_refresh_token"
    private let uidKey     = "sb_user_id"

    private var base: String { Config.supabaseURL + "/auth/v1" }

    // Only ONE sign-in may run at a time. Without this, several callers
    // (app launch + mint + stems…) fire signInAnon() together at a cold
    // launch, each tries to refresh with the SAME single-use refresh token,
    // the losers get a 400, and the app strands the user on a brand-new
    // 3-credit account. Serializing kills that race.
    private var inFlight: Task<Void, Never>?

    init() { userId = UserDefaults.standard.string(forKey: uidKey) }

    /// Ensure we have a valid session for the SAME persistent user.
    /// Concurrent callers all await the single in-flight sign-in.
    func signInAnon() async {
        if accessToken != nil { return }
        if let task = inFlight { await task.value; return }
        let task = Task { await self.performSignIn() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    /// Order: reuse in-memory → refresh the saved session → create one anon user.
    private func performSignIn() async {
        if accessToken != nil { return }
        if let refresh = UserDefaults.standard.string(forKey: refreshKey),
           await refreshSession(refresh) { return }
        await createAnonUser()
    }

    /// Refresh a saved session — keeps the same user id (and their credits).
    private func refreshSession(_ refreshToken: String) async -> Bool {
        guard let url = URL(string: base + "/token?grant_type=refresh_token") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{\"refresh_token\":\"\(refreshToken)\"}".utf8)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200,
               let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = obj["access_token"] as? String {
                store(obj); accessToken = token
                print("session refreshed OK (same user)")
                return true
            }
            print("session refresh failed (\(code)) — creating a fresh anon user")
            return false
        } catch {
            print("session refresh error:", error); return false
        }
    }

    /// Create ONE anonymous user and persist its session.
    private func createAnonUser() async {
        guard let url = URL(string: base + "/signup") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{\"data\":{},\"gotrue_meta_security\":{}}".utf8)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = obj["access_token"] as? String {
                store(obj); accessToken = token
                print("anon sign-in OK (\(code)) user=\(userId ?? "?")")
            } else {
                print("anon sign-in unexpected (\(code)):", String(data: data, encoding: .utf8) ?? "")
            }
        } catch {
            print("anon sign-in failed:", error)
        }
    }

    /// Save the tokens + user id so the next launch reuses this same account.
    private func store(_ obj: [String: Any]) {
        let d = UserDefaults.standard
        if let t = obj["access_token"]  as? String { d.set(t, forKey: tokenKey) }
        if let r = obj["refresh_token"] as? String { d.set(r, forKey: refreshKey) }
        if let u = obj["user"] as? [String: Any], let id = u["id"] as? String {
            userId = id; d.set(id, forKey: uidKey)
        }
    }

    /// Wipe the saved session (e.g. from Settings "Reset account").
    func signOut() {
        let d = UserDefaults.standard
        d.removeObject(forKey: tokenKey); d.removeObject(forKey: refreshKey); d.removeObject(forKey: uidKey)
        accessToken = nil; userId = nil
    }
}
