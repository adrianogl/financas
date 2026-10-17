import SwiftUI

struct AppLogo: View {
    let layout: AppLogoLayout
    let markSize: CGFloat
    let animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: AppLogoReveal

    init(layout: AppLogoLayout = .stacked, markSize: CGFloat = 88, animated: Bool = true) {
        self.layout = layout
        self.markSize = markSize
        self.animated = animated
        _reveal = State(initialValue: animated ? .hidden : .complete)
    }

    var body: some View {
        Group {
            switch layout {
            case .stacked:
                VStack(spacing: markSize * 0.18) {
                    mark
                    wordmark(size: markSize * 0.39)
                }
            case .horizontal:
                HStack(spacing: markSize * 0.3) {
                    mark
                    wordmark(size: markSize * 0.6)
                }
            }
        }
        .onAppear(perform: animateIn)
    }

    private var mark: some View {
        AppMark(size: markSize, lineProgress: reveal.markLine, areaOpacity: reveal.markArea, dotScale: reveal.markDot)
            .opacity(reveal.markVisible ? 1 : 0)
            .scaleEffect(reveal.markVisible ? 1 : 0.9)
            .offset(y: reveal.markVisible ? 0 : markSize * 0.16)
    }

    private func wordmark(size: CGFloat) -> some View {
        AppWordmark(size: size, lineProgress: reveal.wordLine, dotScale: reveal.wordDot)
            .opacity(reveal.wordVisible ? 1 : 0)
            .offset(y: reveal.wordVisible ? 0 : size * 0.25)
    }

    private func animateIn() {
        guard animated, !reduceMotion else {
            reveal = .complete
            return
        }
        let pop = Animation.spring(response: 0.4, dampingFraction: 0.55)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { reveal.markVisible = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.35)) { reveal.wordVisible = true }
        withAnimation(.easeInOut(duration: 0.9).delay(0.25)) { reveal.markLine = 1 }
        withAnimation(.easeOut(duration: 0.6).delay(0.8)) { reveal.markArea = 1 }
        withAnimation(pop.delay(1.05)) { reveal.markDot = 1 }
        withAnimation(.easeInOut(duration: 0.8).delay(1.15)) { reveal.wordLine = 1 }
        withAnimation(pop.delay(1.85)) { reveal.wordDot = 1 }
    }
}
