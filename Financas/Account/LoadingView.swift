import SwiftUI

struct LoadingView: View {
    var body: some View {
        AppMark(size: 88)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
    }
}
