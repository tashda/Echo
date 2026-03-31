import Foundation

/// Configuration for the self-hosted Supabase backend.
/// Values are injected via Info.plist from the gitignored Secrets.xcconfig.
/// If the keys are missing (open-source clone without Secrets.xcconfig), the app
/// falls back to stub auth and cloud sync is unavailable.
enum SupabaseConfig {
    static let baseURL: URL? = {
        guard let string = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !string.isEmpty,
              !string.contains("your-supabase") else { return nil }
        return URL(string: string)
    }()

    static let anonKey: String? = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.contains("your-supabase") else { return nil }
        return key
    }()

    static let googleClientID: String? = {
        guard let id = Bundle.main.infoDictionary?["GOOGLE_CLIENT_ID"] as? String,
              !id.isEmpty,
              !id.contains("your-google") else { return nil }
        return id
    }()

    /// Whether cloud sync is available (Secrets.xcconfig is configured).
    static var isConfigured: Bool {
        baseURL != nil && anonKey != nil
    }

    /// Custom URL scheme for OAuth redirects back to the app.
    static let redirectURI = "dev.echodb.echo://callback"
}
