import SwiftUI

struct AppBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Theme.background
                Circle()
                    .fill(Theme.blobPrimary)
                    .frame(width: width * 1.1)
                    .position(x: width * 0.1, y: height * 0.08)
                Circle()
                    .fill(Theme.blobSecondary)
                    .frame(width: width * 0.9)
                    .position(x: width * 0.95, y: height * 0.36)
                Circle()
                    .fill(Theme.blobTertiary)
                    .frame(width: width * 1.2)
                    .position(x: width * 0.3, y: height * 0.82)
            }
            .blur(radius: 60)
        }
        .background(Theme.background)
        .ignoresSafeArea()
    }
}
