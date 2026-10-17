import SwiftUI

struct WordmarkLineShape: Shape {
    static let endPoint = CGPoint(x: 0.94, y: 0.18)

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.01, 0.82))
        path.addCurve(to: point(0.47, 0.55), control1: point(0.19, 0.77), control2: point(0.28, 0.45))
        path.addCurve(to: point(Self.endPoint.x, Self.endPoint.y), control1: point(0.66, 0.64), control2: point(0.78, 0.27))
        return path
    }
}
