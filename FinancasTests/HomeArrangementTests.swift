import CoreGraphics
import Testing
@testable import Financas

struct HomeArrangementTests {
    @Test func portraitStacks() {
        #expect(HomeArrangement.make(mode: .regularPortrait, contentWidth: 1032) == .stacked)
    }

    @Test func landscapeFollowsColumns() {
        #expect(HomeArrangement.make(mode: .regularLandscape, contentWidth: 886) == .twoColumns)
        #expect(HomeArrangement.make(mode: .regularLandscape, contentWidth: 1052) == .twoColumns)
        #expect(HomeArrangement.make(mode: .regularLandscape, contentWidth: 1210) == .threeColumns)
    }

    @Test func rowTapOpensSectionOnlyWhenThePanelFits() {
        #expect(HomeArrangement.opensSection(mode: .regularLandscape, contentWidth: 886))
        #expect(!HomeArrangement.opensSection(mode: .regularPortrait, contentWidth: 834))
        #expect(!HomeArrangement.opensSection(mode: .regularLandscape, contentWidth: 600))
    }
}
