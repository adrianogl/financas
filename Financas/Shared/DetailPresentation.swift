import CoreGraphics

enum DetailPresentation: Equatable {
    case panel
    case sheet
    case push

    static func make(mode: LayoutMode, contentWidth: CGFloat) -> DetailPresentation {
        if mode == .compact { return .push }
        return mode.showsDetailPanel(contentWidth: contentWidth) ? .panel : .sheet
    }
}
