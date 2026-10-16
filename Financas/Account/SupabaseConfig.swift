import Foundation

struct SupabaseConfig {
    let url: URL
    let key: String

    init(info: [String: Any]) throws(SupabaseConfigError) {
        guard
            let urlText = info[AccountConstants.urlInfoKey] as? String,
            !urlText.isEmpty,
            let url = URL(string: urlText)
        else { throw .missingURL }

        guard let key = info[AccountConstants.keyInfoKey] as? String, !key.isEmpty else {
            throw .missingKey
        }

        self.url = url
        self.key = key
    }
}
