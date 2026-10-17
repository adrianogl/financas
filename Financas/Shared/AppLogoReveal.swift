import CoreGraphics

struct AppLogoReveal {
    var markVisible: Bool
    var markLine: CGFloat
    var markArea: Double
    var markDot: CGFloat
    var wordVisible: Bool
    var wordLine: CGFloat
    var wordDot: CGFloat

    static let hidden = AppLogoReveal(
        markVisible: false, markLine: 0, markArea: 0, markDot: 0,
        wordVisible: false, wordLine: 0, wordDot: 0
    )
    static let complete = AppLogoReveal(
        markVisible: true, markLine: 1, markArea: 1, markDot: 1,
        wordVisible: true, wordLine: 1, wordDot: 1
    )
}
