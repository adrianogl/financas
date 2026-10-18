import CoreGraphics

enum HomeArrangement: Equatable {
    case stacked
    case twoColumns
    case threeColumns

    static func make(mode: LayoutMode, contentWidth: CGFloat) -> HomeArrangement {
        if mode == .regularPortrait { return .stacked }
        return HomeLayout.columns(contentWidth: contentWidth) == 3 ? .threeColumns : .twoColumns
    }

    static func opensSection(mode: LayoutMode, contentWidth: CGFloat) -> Bool {
        DetailPresentation.make(mode: mode, contentWidth: contentWidth) == .panel
    }
}
