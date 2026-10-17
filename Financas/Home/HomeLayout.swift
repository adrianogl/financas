import CoreGraphics

enum HomeLayout {
    static func columns(contentWidth: CGFloat) -> Int {
        contentWidth >= LayoutConstants.homeThreeColumnMinWidth ? 3 : 2
    }
}
