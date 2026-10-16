import SwiftUI

struct AppMark: View {
    var size: CGFloat = 64

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [Theme.markTop, Theme.markBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                BalanceLineShape(closesArea: true)
                    .fill(LinearGradient(colors: [Theme.accent.opacity(0.35), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                BalanceLineShape()
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round))
                Circle()
                    .fill(Theme.accent)
                    .frame(width: size * 0.12, height: size * 0.12)
                    .position(x: size * 0.86, y: size * 0.28)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.12), radius: size * 0.12, y: size * 0.06)
            .accessibilityHidden(true)
    }
}
