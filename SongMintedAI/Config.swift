import Foundation

// Live backend config. useRealBackend = true makes Mint call Supabase → EvoLink.
enum Config {
    static let useRealBackend = true
    // Flip to true once the Higgsfield secrets + "videos" bucket are set up.
    static let cinematicVideoEnabled = true
    // Flip to true once the /stems edge function is deployed.
    static let stemsEnabled = true
    static let supabaseURL = "https://ucnruxztueysdohgamdy.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVjbnJ1eHp0dWV5c2RvaGdhbWR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTE2NzcsImV4cCI6MjA5OTI2NzY3N30.-fJF0jiS4avyWvXE6VLKZCpVECjultBteNAIxXogCfM"
}
