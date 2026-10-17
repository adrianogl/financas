enum DetailSelection {
    static func resolve(current: String?, ids: [String], openIDs: [String]) -> String? {
        if let current, ids.contains(current) { return current }
        return openIDs.first ?? ids.first
    }
}
