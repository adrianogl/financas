import Foundation
import Testing
@testable import Financas

struct SupabaseConfigTests {
    @Test func readsURLAndKey() throws {
        let config = try SupabaseConfig(info: ["SupabaseURL": "https://abc.supabase.co", "SupabaseKey": "pk"])

        #expect(config.url.absoluteString == "https://abc.supabase.co")
        #expect(config.key == "pk")
    }

    @Test func missingURLThrows() {
        #expect(throws: SupabaseConfigError.missingURL) {
            try SupabaseConfig(info: ["SupabaseKey": "pk"])
        }
        #expect(throws: SupabaseConfigError.missingURL) {
            try SupabaseConfig(info: ["SupabaseURL": "", "SupabaseKey": "pk"])
        }
    }

    @Test func missingKeyThrows() {
        #expect(throws: SupabaseConfigError.missingKey) {
            try SupabaseConfig(info: ["SupabaseURL": "https://abc.supabase.co"])
        }
    }
}
