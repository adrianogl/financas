import Foundation
import Testing
@testable import Financas

struct AppVersionTests {
    private let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!

    @Test func showsVersionCommitAndBuildDate() {
        let version = AppVersion(info: [
            "CFBundleShortVersionString": "0.1.0",
            SettingsConstants.commitKey: "2574ebf",
            SettingsConstants.builtAtKey: "2026-10-18T17:32:00Z"
        ])
        #expect(version.text(timeZone: saoPaulo) == "0.1.0 · 2574ebf · 18/10, 14:32")
    }

    @Test func marksUncommittedChanges() {
        let version = AppVersion(info: ["CFBundleShortVersionString": "0.1.0", SettingsConstants.commitKey: "2574ebf+"])
        #expect(version.text(timeZone: saoPaulo) == "0.1.0 · 2574ebf+")
    }

    @Test func fallsBackToVersionOnly() {
        #expect(AppVersion(info: ["CFBundleShortVersionString": "0.1.0"]).text() == "0.1.0")
        #expect(AppVersion(info: [:]).text() == "—")
    }
}
