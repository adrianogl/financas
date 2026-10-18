import SwiftUI

struct AppSidebarHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            AppMark(size: NavigationConstants.sidebarMarkSize)
            Text("Finanças")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .accessibilityElement(children: .combine)
    }
}
