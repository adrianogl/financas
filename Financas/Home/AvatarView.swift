import SwiftUI
import UIKit

struct AvatarView: View {
    let initial: String
    let imageData: Data?
    var isUploading = false
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Theme.markBottom
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
            if isUploading {
                Color.black.opacity(0.25)
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
