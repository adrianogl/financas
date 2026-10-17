import Foundation
import Supabase

@MainActor
final class SupabaseAvatarService: AvatarService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(_ data: Data, userID: String, version: Int) async throws(AvatarError) {
        do {
            try await bucket.upload(path(userID, version), data: data, options: FileOptions(contentType: AvatarConstants.contentType, upsert: true))
        } catch {
            throw Self.avatarError(from: error)
        }
    }

    func download(userID: String, version: Int) async throws(AvatarError) -> Data {
        do {
            return try await bucket.download(path: path(userID, version))
        } catch {
            throw Self.avatarError(from: error)
        }
    }

    func remove(userID: String, version: Int) async throws(AvatarError) {
        do {
            try await bucket.remove(paths: [path(userID, version)])
        } catch {
            throw Self.avatarError(from: error)
        }
    }

    private var bucket: StorageFileApi {
        client.storage.from(AvatarConstants.bucket)
    }

    private func path(_ userID: String, _ version: Int) -> String {
        "\(userID.lowercased())/\(version).\(AvatarConstants.fileExtension)"
    }

    nonisolated static func avatarError(from error: any Error) -> AvatarError {
        error is URLError ? .network : .unknown
    }
}
