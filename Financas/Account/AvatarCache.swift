import Foundation

struct AvatarCache {
    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static var standard: AvatarCache {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return AvatarCache(directory: caches.appending(path: AvatarConstants.cacheFolder))
    }

    func load() -> (version: Int, userID: String, data: Data)? {
        guard
            let versionText = try? String(contentsOf: url(AvatarConstants.versionFileName), encoding: .utf8),
            let version = Int(versionText),
            let userID = try? String(contentsOf: url(AvatarConstants.ownerFileName), encoding: .utf8),
            let data = try? Data(contentsOf: url(AvatarConstants.fileName))
        else { return nil }
        return (version, userID, data)
    }

    func save(_ data: Data, version: Int, userID: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(AvatarConstants.fileName), options: .atomic)
        try? String(version).write(to: url(AvatarConstants.versionFileName), atomically: true, encoding: .utf8)
        try? userID.write(to: url(AvatarConstants.ownerFileName), atomically: true, encoding: .utf8)
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func url(_ name: String) -> URL {
        directory.appending(path: name)
    }
}
