import CoreGraphics

enum LayoutMode: Equatable {
    case compact
    case regularPortrait
    case regularLandscape

    static func make(isRegular: Bool, size: CGSize) -> LayoutMode {
        guard isRegular else { return .compact }
        return size.width > size.height ? .regularLandscape : .regularPortrait
    }

    func showsDetailPanel(contentWidth: CGFloat) -> Bool {
        self == .regularLandscape && contentWidth >= LayoutConstants.detailPanelMinWidth
    }
}
