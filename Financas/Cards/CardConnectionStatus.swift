enum CardConnectionStatus: String, Codable, Sendable {
    case active
    case needsReconnect = "needs_reconnect"
    case error
}
