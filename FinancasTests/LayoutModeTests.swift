import CoreGraphics
import Testing
@testable import Financas

struct LayoutModeTests {
    @Test func compactIgnoresSize() {
        #expect(LayoutMode.make(isRegular: false, size: CGSize(width: 1210, height: 834)) == .compact)
    }

    @Test func regularUsesWindowShape() {
        #expect(LayoutMode.make(isRegular: true, size: CGSize(width: 1210, height: 834)) == .regularLandscape)
        #expect(LayoutMode.make(isRegular: true, size: CGSize(width: 1032, height: 1376)) == .regularPortrait)
    }

    @Test func detailPanelOnlyInWideLandscape() {
        #expect(LayoutMode.regularLandscape.showsDetailPanel(contentWidth: 890))
        #expect(!LayoutMode.regularLandscape.showsDetailPanel(contentWidth: 600))
        #expect(!LayoutMode.regularPortrait.showsDetailPanel(contentWidth: 1032))
        #expect(!LayoutMode.compact.showsDetailPanel(contentWidth: 1000))
    }

    @Test func homeColumnsByContentWidth() {
        #expect(HomeLayout.columns(contentWidth: 890) == 2)
        #expect(HomeLayout.columns(contentWidth: 1056) == 2)
        #expect(HomeLayout.columns(contentWidth: 1210) == 3)
        #expect(HomeLayout.columns(contentWidth: 1376) == 3)
    }
}
