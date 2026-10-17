import Foundation
import Observation

@MainActor
@Observable
final class AvatarStore {
    private(set) var imageData: Data?
    private(set) var isUploading = false
    private(set) var errorMessage: String?

    private let service: AvatarService
    private let cache: AvatarCache
    private let now: () -> Date
    private let updateVersion: (Int?) async throws(AccountError) -> AccountUser

    init(
        service: AvatarService,
        cache: AvatarCache,
        now: @escaping () -> Date = Date.init,
        updateVersion: @escaping (Int?) async throws(AccountError) -> AccountUser
    ) {
        self.service = service
        self.cache = cache
        self.now = now
        self.updateVersion = updateVersion
    }

    static func initial(for user: AccountUser) -> String {
        let name = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = name.isEmpty ? user.email.trimmingCharacters(in: .whitespacesAndNewlines) : name
        return source.first.map { String($0).uppercased() } ?? "?"
    }

    func sync(user: AccountUser) async {
        guard let version = user.avatarVersion else {
            cache.clear()
            imageData = nil
            return
        }
        let cached = cache.load()
        if let cached, cached.version == version {
            imageData = cached.data
            return
        }
        if imageData == nil {
            imageData = cached?.data
        }
        guard let data = try? await service.download(userID: user.id) else { return }
        cache.save(data, version: version)
        imageData = data
    }

    func upload(_ data: Data, for user: AccountUser) async -> AccountUser? {
        guard !isUploading else { return nil }
        guard let jpeg = AvatarImageResizer.jpegData(from: data) else {
            errorMessage = AvatarError.unknown.uploadMessage
            return nil
        }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        do throws(AvatarError) {
            try await service.upload(jpeg, userID: user.id)
            let version = Int(now().timeIntervalSince1970)
            let updated: AccountUser
            do {
                updated = try await updateVersion(version)
            } catch {
                throw AvatarError(error)
            }
            cache.save(jpeg, version: version)
            imageData = jpeg
            return updated
        } catch {
            errorMessage = error.uploadMessage
            return nil
        }
    }

    func remove(for user: AccountUser) async -> AccountUser? {
        guard !isUploading else { return nil }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        do throws(AvatarError) {
            try await service.remove(userID: user.id)
            let updated: AccountUser
            do {
                updated = try await updateVersion(nil)
            } catch {
                throw AvatarError(error)
            }
            cache.clear()
            imageData = nil
            return updated
        } catch {
            errorMessage = error.removeMessage
            return nil
        }
    }

    func reset() {
        cache.clear()
        imageData = nil
        errorMessage = nil
    }
}
