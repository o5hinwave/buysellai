import Foundation

#if canImport(Supabase)
import Supabase

extension AppConfig {
    func makeSupabaseClient() -> SupabaseClient {
        SupabaseClient(supabaseURL: supabaseURL, supabaseKey: anonKey)
    }
}
#endif
