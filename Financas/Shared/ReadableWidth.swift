import SwiftUI

extension View {
    func readableWidth(_ width: CGFloat = LayoutConstants.formWidth) -> some View {
        frame(maxWidth: width)
            .frame(maxWidth: .infinity)
    }
}
