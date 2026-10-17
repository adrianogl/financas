import SwiftUI

struct CollapsingAppLogo: View {
    var markSize: CGFloat = 44
    var isVisible = true

    @MainActor private static var hasPlayed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsWordmark = !CollapsingAppLogo.hasPlayed

    var body: some View {
        let spacing = markSize * 0.3
        ZStack(alignment: .leading) {
            AppWordmark(size: markSize * 0.6)
                .padding(.leading, markSize + spacing)
                .offset(x: showsWordmark ? 0 : -(markSize + spacing))
                .scaleEffect(showsWordmark ? 1 : 0.85, anchor: .leading)
                .opacity(showsWordmark ? 1 : 0)
                .accessibilityHidden(!showsWordmark)
            AppMark(size: markSize)
                .zIndex(1)
        }
        .task(id: isVisible) {
            guard isVisible, showsWordmark else { return }
            Self.hasPlayed = true
            guard !reduceMotion else {
                showsWordmark = false
                return
            }
            guard (try? await Task.sleep(for: .seconds(1.6))) != nil else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                showsWordmark = false
            }
        }
    }
}
