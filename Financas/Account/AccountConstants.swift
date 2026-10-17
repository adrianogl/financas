import Foundation

enum AccountConstants {
    static let redirectURL = URL(string: "financas://auth-callback")!
    static let recoveryRedirectURL = URL(string: "financas://auth-callback/recovery")!
    static let recoveryPath = "/recovery"
    static let minimumPasswordLength = 8
    static let installMarkerKey = "install.v2"
    static let legacyNameKey = "profile.name"
    static let nameMetadataKey = "name"
    static let avatarVersionMetadataKey = "avatar_version"
    static let urlInfoKey = "SupabaseURL"
    static let keyInfoKey = "SupabaseKey"
}
