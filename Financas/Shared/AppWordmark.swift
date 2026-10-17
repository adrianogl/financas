import SwiftUI

struct AppWordmark: View {
    var size: CGFloat = 34
    var lineProgress: CGFloat = 1
    var dotScale: CGFloat = 1

    var body: some View {
        Text("Finanças")
            .font(.system(size: size, weight: .bold))
            .tracking(-size * 0.03)
            .padding(.trailing, size * 0.3)
            .padding(.bottom, size * 0.38)
            .overlay(alignment: .bottom) {
                GeometryReader { proxy in
                    let lineWidth = size * 0.075
                    let dotSize = size * 0.19
                    WordmarkLineShape()
                        .trim(from: 0, to: lineProgress)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(dotScale)
                        .position(
                            x: proxy.size.width * WordmarkLineShape.endPoint.x,
                            y: proxy.size.height * WordmarkLineShape.endPoint.y
                        )
                }
                .frame(height: size * 0.5)
                .accessibilityHidden(true)
            }
    }
}
