import Foundation

@MainActor
protocol AvatarService {
    func upload(_ data: Data, userID: String, version: Int) async throws(AvatarError)
    func download(userID: String, version: Int) async throws(AvatarError) -> Data
    func remove(userID: String, version: Int) async throws(AvatarError)
}
