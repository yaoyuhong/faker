import Foundation

enum AppConfig {
    private static let baseURLKey = "courtlog.apiBaseURL"

    /// CV service base URL. Simulator → Mac localhost; device → your LAN IP.
    static var apiBaseURL: URL {
        if let saved = UserDefaults.standard.string(forKey: baseURLKey),
           let url = URL(string: saved) {
            return url
        }
        return URL(string: "http://127.0.0.1:8000/v1")!
    }

    static func setAPIBaseURL(_ string: String) {
        UserDefaults.standard.set(string, forKey: baseURLKey)
    }
}
