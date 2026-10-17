import SwiftUI

struct AppSidebarRow: View {
    let section: AppTab
    let count: Int

    var body: some View {
        HStack {
            Label(section.title, systemImage: section.systemImage)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .monospacedDigit()
                    .fontWeight(section == .overdue ? .semibold : .regular)
                    .foregroundStyle(section == .overdue ? Theme.warning : .secondary)
            }
        }
    }
}
