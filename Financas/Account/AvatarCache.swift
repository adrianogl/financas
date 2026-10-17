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

    func load() -> (version: Int, data: Data)? {
        guard
            let versionText = try? String(contentsOf: versionURL, encoding: .utf8),
            let version = Int(versionText),
            let data = try? Data(contentsOf: imageURL)
        else { return nil }
        return (version, data)
    }

    func save(_ data: Data, version: Int) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: imageURL, options: .atomic)
        try? String(version).write(to: versionURL, atomically: true, encoding: .utf8)
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    private var imageURL: URL {
        directory.appending(path: AvatarConstants.fileName)
    }

    private var versionURL: URL {
        directory.appending(path: AvatarConstants.versionFileName)
    }
}
