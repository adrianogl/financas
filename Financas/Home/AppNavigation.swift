import Foundation
import Observation

@MainActor
@Observable
final class AppNavigation {
    var section: AppTab = .home
    var isSidebarOpen: Bool {
        didSet { defaults.set(isSidebarOpen, forKey: NavigationConstants.sidebarOpenKey) }
    }
    var pendingSelection: DetailRoute?
    private(set) var mode: LayoutMode = .compact
    private var isPortraitSidebarOpen = false
    private var listDetail: [AppTab: ListDetailState] = [:]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isSidebarOpen = defaults.object(forKey: NavigationConstants.sidebarOpenKey) as? Bool ?? true
    }

    var isSidebarVisible: Bool {
        showsSidebar(in: mode)
    }

    func open(_ route: DetailRoute) {
        section = route.section
        pendingSelection = route
    }

    func takeSelection(for section: AppTab) -> DetailRoute? {
        guard let route = pendingSelection, route.section == section else { return nil }
        pendingSelection = nil
        return route
    }

    func showsSidebar(in mode: LayoutMode) -> Bool {
        switch mode {
        case .compact:
            false
        case .regularPortrait:
            isPortraitSidebarOpen
        case .regularLandscape:
            isSidebarOpen
        }
    }

    func setSidebar(open: Bool, in mode: LayoutMode) {
        switch mode {
        case .compact:
            break
        case .regularPortrait:
            isPortraitSidebarOpen = open
        case .regularLandscape:
            isSidebarOpen = open
        }
    }

    func toggleSidebar() {
        setSidebar(open: !isSidebarVisible, in: mode)
    }

    func enter(_ mode: LayoutMode) {
        if mode != self.mode && mode == .regularPortrait {
            isPortraitSidebarOpen = false
        }
        self.mode = mode
    }

    func selection(for section: AppTab) -> DetailRoute? {
        listDetail[section]?.selection
    }

    func isSheetPresented(in section: AppTab) -> Bool {
        listDetail[section]?.isSheetPresented ?? false
    }

    func select(_ route: DetailRoute, in section: AppTab, presentation: DetailPresentation) {
        listDetail[section, default: ListDetailState()].select(route, presentation: presentation)
    }

    func applyDefaultSelection(routes: [DetailRoute], openRoutes: [DetailRoute], in section: AppTab) {
        listDetail[section, default: ListDetailState()].applyDefault(routes: routes, openRoutes: openRoutes)
    }

    func presentationChanged(from old: DetailPresentation, to new: DetailPresentation, in section: AppTab) {
        listDetail[section, default: ListDetailState()].presentationChanged(from: old, to: new, isActive: section == self.section)
    }

    func dismissSheet(in section: AppTab) {
        listDetail[section]?.dismissSheet()
    }
}
