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
    private var generation = 0

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
        let cached = cache.load().flatMap { $0.userID == user.id ? $0 : nil }
        if let cached, cached.version == version {
            imageData = cached.data
            return
        }
        imageData = cached?.data
        let started = generation
        guard let data = try? await service.download(userID: user.id, version: version),
              started == generation, !Task.isCancelled else { return }
        cache.save(data, version: version, userID: user.id)
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
        let started = generation
        let version = Int(now().timeIntervalSince1970)

        do throws(AvatarError) {
            try await service.upload(jpeg, userID: user.id, version: version)
            guard started == generation else { return nil }
            let updated: AccountUser
            do {
                updated = try await updateVersion(version)
            } catch {
                try? await service.remove(userID: user.id, version: version)
                throw AvatarError(error)
            }
            guard started == generation else { return nil }
            cache.save(jpeg, version: version, userID: user.id)
            imageData = jpeg
            if let previous = user.avatarVersion, previous != version {
                try? await service.remove(userID: user.id, version: previous)
            }
            return updated
        } catch {
            guard started == generation else { return nil }
            errorMessage = error.uploadMessage
            return nil
        }
    }

    func remove(for user: AccountUser) async -> AccountUser? {
        guard !isUploading else { return nil }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        let started = generation

        do throws(AvatarError) {
            if let version = user.avatarVersion {
                try await service.remove(userID: user.id, version: version)
            }
            let updated: AccountUser
            do {
                updated = try await updateVersion(nil)
            } catch {
                throw AvatarError(error)
            }
            guard started == generation else { return nil }
            cache.clear()
            imageData = nil
            return updated
        } catch {
            guard started == generation else { return nil }
            errorMessage = error.removeMessage
            return nil
        }
    }

    func reset() {
        generation += 1
        cache.clear()
        imageData = nil
        errorMessage = nil
    }
}
