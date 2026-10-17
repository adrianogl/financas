import Foundation
import Testing
import UIKit
@testable import Financas

@MainActor
struct AvatarStoreTests {
    private let photo: Data = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600), format: format).pngData { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
        }
    }()

    private func makeStore(service: FakeAvatarService = FakeAvatarService()) -> (AvatarStore, FakeAvatarService, AvatarCache, AvatarVersionRecorder) {
        let cache = AvatarCache(directory: FileManager.default.temporaryDirectory.appending(path: "avatar-\(UUID().uuidString)"))
        let box = AvatarVersionRecorder()
        let store = AvatarStore(service: service, cache: cache, now: { Date(timeIntervalSince1970: 1_800_000_000) }) { version throws(AccountError) in
            box.versions.append(version)
            if let error = box.error { throw error }
            var user = AccountUser.sample
            user.avatarVersion = version
            return user
        }
        return (store, service, cache, box)
    }

    private func user(version: Int?) -> AccountUser {
        var user = AccountUser.sample
        user.avatarVersion = version
        return user
    }

    @Test func initialFromNameOrEmail() {
        #expect(AvatarStore.initial(for: AccountUser(id: "1", email: "eu@x", name: " adriano")) == "A")
        #expect(AvatarStore.initial(for: AccountUser(id: "1", email: "zoe@x", name: "")) == "Z")
        #expect(AvatarStore.initial(for: AccountUser(id: "1", email: "", name: "")) == "?")
    }

    @Test func syncWithoutVersionClearsCache() async {
        let (store, _, cache, _) = makeStore()
        cache.save(Data([1]), version: 1, userID: "u1")
        await store.sync(user: user(version: nil))
        #expect(store.imageData == nil)
        #expect(cache.load() == nil)
    }

    @Test func syncUsesCacheWhenVersionMatches() async {
        let (store, service, cache, _) = makeStore()
        cache.save(Data([7]), version: 5, userID: "u1")
        await store.sync(user: user(version: 5))
        #expect(store.imageData == Data([7]))
        #expect(service.downloadedVersions.isEmpty)
    }

    @Test func newVersionDownloadsAgain() async {
        let (store, service, cache, _) = makeStore()
        cache.save(Data([7]), version: 5, userID: "u1")
        service.files[6] = Data([8])
        await store.sync(user: user(version: 6))
        #expect(store.imageData == Data([8]))
        #expect(cache.load()?.version == 6)
        #expect(service.downloadedVersions == [6])
    }

    @Test func downloadFailureKeepsCachedImage() async {
        let (store, service, cache, _) = makeStore()
        cache.save(Data([7]), version: 5, userID: "u1")
        service.nextError = .network
        await store.sync(user: user(version: 6))
        #expect(store.imageData == Data([7]))
        #expect(cache.load()?.version == 5)
    }

    @Test func uploadSavesAndUpdatesVersion() async throws {
        let (store, service, cache, box) = makeStore()
        let updated = try #require(await store.upload(photo, for: .sample))
        #expect(updated.avatarVersion == 1_800_000_000)
        #expect(box.versions == [1_800_000_000])
        #expect(service.uploads.count == 1)
        #expect(service.uploads.first?.version == 1_800_000_000)
        #expect(UIImage(data: try #require(service.uploads.first?.data))?.size == CGSize(width: 512, height: 512))
        #expect(store.imageData == service.uploads.first?.data)
        #expect(cache.load()?.version == 1_800_000_000)
    }

    @Test func ignoresSecondUploadWhileUploading() async {
        let (store, service, _, _) = makeStore()
        service.holdsResponses = true
        let first = Task { await store.upload(photo, for: .sample) }
        for _ in 0..<10 { await Task.yield() }
        let second = await store.upload(photo, for: .sample)
        service.release()
        _ = await first.value
        #expect(second == nil)
        #expect(service.uploads.count == 1)
    }

    @Test func uploadFailureShowsMessage() async {
        let (store, service, _, box) = makeStore()
        service.nextError = .network
        let result = await store.upload(photo, for: .sample)
        #expect(result == nil)
        #expect(store.errorMessage == AvatarError.network.uploadMessage)
        #expect(box.versions.isEmpty)
    }

    @Test func removeClearsEverything() async throws {
        let (store, service, cache, box) = makeStore()
        _ = await store.upload(photo, for: .sample)
        let updated = try #require(await store.remove(for: user(version: 1_800_000_000)))
        #expect(updated.avatarVersion == nil)
        #expect(box.versions.last == .some(nil))
        #expect(service.removedVersions == [1_800_000_000])
        #expect(store.imageData == nil)
        #expect(cache.load() == nil)
    }

    @Test func resetClearsImageAndCache() async {
        let (store, _, cache, _) = makeStore()
        _ = await store.upload(photo, for: .sample)
        store.reset()
        #expect(store.imageData == nil)
        #expect(cache.load() == nil)
        #expect(store.errorMessage == nil)
    }

    @Test func uploadRemovesPreviousVersion() async {
        let (store, service, _, _) = makeStore()
        service.files[5] = Data([5])
        _ = await store.upload(photo, for: user(version: 5))
        #expect(service.removedVersions == [5])
        #expect(service.files[5] == nil)
        #expect(service.files[1_800_000_000] != nil)
    }

    @Test func versionFailureRemovesNewFile() async {
        let (store, service, cache, box) = makeStore()
        service.files[5] = Data([5])
        cache.save(Data([5]), version: 5, userID: "u1")
        await store.sync(user: user(version: 5))
        box.error = .network

        let result = await store.upload(photo, for: user(version: 5))

        #expect(result == nil)
        #expect(service.removedVersions == [1_800_000_000])
        #expect(service.files[5] == Data([5]))
        #expect(store.imageData == Data([5]))
        #expect(cache.load()?.version == 5)
        #expect(store.errorMessage == AvatarError.network.uploadMessage)
    }

    @Test func cacheOfOtherUserIsIgnored() async {
        let (store, service, cache, _) = makeStore()
        cache.save(Data([9]), version: 5, userID: "outra")
        service.nextError = .network
        await store.sync(user: user(version: 5))
        #expect(store.imageData == nil)
        #expect(service.downloadedVersions == [5])
    }

    @Test func resetDuringDownloadDiscardsResult() async {
        let (store, service, cache, _) = makeStore()
        service.files[6] = Data([6])
        service.holdsResponses = true
        let syncing = Task { await store.sync(user: user(version: 6)) }
        for _ in 0..<10 { await Task.yield() }
        store.reset()
        service.release()
        await syncing.value
        #expect(store.imageData == nil)
        #expect(cache.load() == nil)
    }

    @Test func resetDuringUploadDiscardsResult() async {
        let (store, service, cache, _) = makeStore()
        service.holdsResponses = true
        let uploading = Task { await store.upload(photo, for: .sample) }
        for _ in 0..<10 { await Task.yield() }
        store.reset()
        service.release()
        let result = await uploading.value
        #expect(result == nil)
        #expect(store.imageData == nil)
        #expect(cache.load() == nil)
    }
}
