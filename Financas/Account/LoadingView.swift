import SwiftUI

struct LoadingView: View {
    var body: some View {
        AppLogo(markSize: 88)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
    }
}
