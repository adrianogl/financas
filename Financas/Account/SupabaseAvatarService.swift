import Foundation
import Supabase

@MainActor
final class SupabaseAvatarService: AvatarService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(_ data: Data, userID: String) async throws(AvatarError) {
        do {
            try await bucket.upload(path(userID), data: data, options: FileOptions(contentType: AvatarConstants.contentType, upsert: true))
        } catch {
            throw Self.avatarError(from: error)
        }
    }

    func download(userID: String) async throws(AvatarError) -> Data {
        do {
            return try await bucket.download(path: path(userID))
        } catch {
            throw Self.avatarError(from: error)
        }
    }

    func remove(userID: String) async throws(AvatarError) {
        do {
            try await bucket.remove(paths: [path(userID)])
        } catch {
            throw Self.avatarError(from: error)
        }
    }

    private var bucket: StorageFileApi {
        client.storage.from(AvatarConstants.bucket)
    }

    private func path(_ userID: String) -> String {
        "\(userID.lowercased())/\(AvatarConstants.fileName)"
    }

    nonisolated static func avatarError(from error: any Error) -> AvatarError {
        error is URLError ? .network : .unknown
    }
}
