import Testing
@testable import Financas

struct ListDetailStateTests {
    private let october = YearMonth(year: 2026, month: 10)

    private func income(_ id: String) -> DetailRoute {
        .income(id: id, month: october)
    }

    @Test func defaultPicksFirstOpenAndIsNotByUser() {
        var state = ListDetailState()
        state.applyDefault(routes: [income("a"), income("b")], openRoutes: [income("b")])
        #expect(state.selection == income("b"))
        #expect(!state.isSelectedByUser)
    }

    @Test func defaultKeepsUserSelectionWhileItStaysInTheList() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        state.applyDefault(routes: [income("a"), income("b")], openRoutes: [income("b")])
        #expect(state.selection == income("a"))
        #expect(state.isSelectedByUser)
    }

    @Test func defaultReplacesSelectionMissingFromTheNewMonth() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        state.applyDefault(routes: [income("c")], openRoutes: [])
        #expect(state.selection == income("c"))
        #expect(!state.isSelectedByUser)
    }

    @Test func emptyMonthClearsSelection() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        state.applyDefault(routes: [], openRoutes: [])
        #expect(state.selection == nil)
    }

    @Test func tapOpensSheetOnlyWithoutPanel() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        #expect(!state.isSheetPresented)
        state.select(income("b"), presentation: .sheet)
        #expect(state.isSheetPresented)
        state.select(income("c"), presentation: .push)
        #expect(!state.isSheetPresented)
    }

    @Test func losingPanelOpensSheetForUserSelection() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        state.presentationChanged(from: .panel, to: .sheet, isActive: true)
        #expect(state.isSheetPresented)
        state.presentationChanged(from: .sheet, to: .panel, isActive: true)
        #expect(!state.isSheetPresented)
        #expect(state.selection == income("a"))
        #expect(state.isSelectedByUser)
    }

    @Test func losingPanelKeepsAutomaticSelectionInTheList() {
        var state = ListDetailState()
        state.applyDefault(routes: [income("a")], openRoutes: [income("a")])
        state.presentationChanged(from: .panel, to: .sheet, isActive: true)
        #expect(!state.isSheetPresented)
    }

    @Test func hiddenSectionDoesNotOpenSheet() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        state.presentationChanged(from: .panel, to: .sheet, isActive: false)
        #expect(!state.isSheetPresented)
    }

    @Test func compactClosesSheet() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .sheet)
        state.presentationChanged(from: .sheet, to: .push, isActive: true)
        #expect(!state.isSheetPresented)
        #expect(state.selection == income("a"))
    }

    @Test func userDismissForgetsTapButKeepsSelection() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .sheet)
        state.dismissSheet()
        #expect(!state.isSheetPresented)
        #expect(!state.isSelectedByUser)
        #expect(state.selection == income("a"))
        state.presentationChanged(from: .sheet, to: .panel, isActive: true)
        state.presentationChanged(from: .panel, to: .sheet, isActive: true)
        #expect(!state.isSheetPresented)
    }

    @Test func dismissAfterRotationKeepsTap() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        state.presentationChanged(from: .panel, to: .sheet, isActive: true)
        state.presentationChanged(from: .sheet, to: .panel, isActive: true)
        state.dismissSheet()
        #expect(state.isSelectedByUser)
    }

    @Test func emptyRoutesWhileLoadingDoNotClearSelection() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        state.applyDefault(routes: [], openRoutes: [], isLoaded: false)
        #expect(state.selection == income("a"))
        #expect(state.isSelectedByUser)
        state.applyDefault(routes: [income("b"), income("a")], openRoutes: [income("b")])
        #expect(state.selection == income("a"))
    }

    @Test func unknownPreviousPresentationClosesSheetInCompact() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .sheet)
        state.presentationChanged(from: nil, to: .push, isActive: true)
        #expect(!state.isSheetPresented)
        #expect(state.selection == income("a"))
    }

    @Test func unknownPreviousPresentationDoesNotOpenSheet() {
        var state = ListDetailState()
        state.select(income("a"), presentation: .panel)
        state.presentationChanged(from: nil, to: .sheet, isActive: true)
        #expect(!state.isSheetPresented)
    }
}
