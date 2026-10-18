import Testing
@testable import Financas

struct DetailPresentationTests {
    @Test func compactPushes() {
        #expect(DetailPresentation.make(mode: .compact, contentWidth: 1000) == .push)
    }

    @Test func wideLandscapeShowsPanel() {
        #expect(DetailPresentation.make(mode: .regularLandscape, contentWidth: 890) == .panel)
    }

    @Test func narrowLandscapeUsesSheet() {
        #expect(DetailPresentation.make(mode: .regularLandscape, contentWidth: 600) == .sheet)
    }

    @Test func portraitUsesSheet() {
        #expect(DetailPresentation.make(mode: .regularPortrait, contentWidth: 1032) == .sheet)
    }
}
