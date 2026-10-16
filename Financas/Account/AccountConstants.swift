import Foundation

enum AccountConstants {
    static let redirectURL = URL(string: "financas://auth-callback")!
    static let minimumPasswordLength = 8
    static let installMarkerKey = "install.v2"
    static let legacyNameKey = "profile.name"
    static let nameMetadataKey = "name"
    static let urlInfoKey = "SupabaseURL"
    static let keyInfoKey = "SupabaseKey"
}
