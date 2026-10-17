import SwiftUI

struct AppSidebarHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            AppMark(size: NavigationConstants.sidebarMarkSize)
            Text("Finanças")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
