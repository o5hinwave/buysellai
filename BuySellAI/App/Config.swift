import Foundation

struct AppConfig: Sendable {
    let supabaseURL: URL
    let anonKey: String

    var functionsBaseURL: URL {
        supabaseURL.appending(path: "functions").appending(path: "v1")
    }

    static func load() throws -> AppConfig {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist") else {
            throw APIError.notConfigured
        }
        let data = try Data(contentsOf: url)
        guard
            let dictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let supabaseURLString = dictionary["SUPABASE_URL"] as? String,
            let anonKey = dictionary["SUPABASE_ANON_KEY"] as? String
        else {
            throw APIError.notConfigured
        }
        return try AppConfig.make(supabaseURLString: supabaseURLString, anonKey: anonKey)
    }

    static func make(supabaseURLString: String, anonKey: String) throws -> AppConfig {
        let trimmedURL = supabaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnonKey = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let components = URLComponents(string: trimmedURL),
            components.scheme == "https",
            let host = components.host?.lowercased(),
            Self.isProjectSupabaseHost(host),
            components.user == nil,
            components.password == nil,
            components.port == nil,
            components.path.isEmpty || components.path == "/",
            components.query == nil,
            components.fragment == nil,
            let supabaseURL = URL(string: "https://\(host)"),
            trimmedAnonKey.isEmpty == false
        else {
            throw APIError.notConfigured
        }
        return AppConfig(supabaseURL: supabaseURL, anonKey: trimmedAnonKey)
    }

    private static func isProjectSupabaseHost(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count == 3, parts[1] == "supabase", parts[2] == "co" else {
            return false
        }
        return parts[0].range(of: #"^[a-z0-9-]+$"#, options: .regularExpression) != nil
    }
}
