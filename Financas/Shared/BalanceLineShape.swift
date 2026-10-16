import SwiftUI

struct BalanceLineShape: Shape {
    var closesArea = false

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.14, 0.70))
        path.addCurve(to: point(0.50, 0.52), control1: point(0.30, 0.66), control2: point(0.36, 0.48))
        path.addCurve(to: point(0.86, 0.28), control1: point(0.64, 0.56), control2: point(0.72, 0.30))
        if closesArea {
            path.addLine(to: point(0.86, 0.86))
            path.addLine(to: point(0.14, 0.86))
            path.closeSubpath()
        }
        return path
    }
}
