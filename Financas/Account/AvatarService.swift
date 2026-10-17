import Foundation

@MainActor
protocol AvatarService {
    func upload(_ data: Data, userID: String) async throws(AvatarError)
    func download(userID: String) async throws(AvatarError) -> Data
    func remove(userID: String) async throws(AvatarError)
}
