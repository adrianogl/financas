import Foundation
import Supabase

enum SupabaseClientFactory {
    static func make(config: SupabaseConfig) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.key,
            options: SupabaseClientOptions(
                db: .init(encoder: SupabaseIncomeService.encoder, decoder: SupabaseIncomeService.decoder),
                auth: .init(
                    redirectToURL: AccountConstants.redirectURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
