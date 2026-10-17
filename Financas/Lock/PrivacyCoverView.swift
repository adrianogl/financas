import SwiftUI

struct PrivacyCoverView: View {
    var body: some View {
        AppLogo(markSize: 88, animated: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
    }
}
