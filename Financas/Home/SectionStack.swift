import SwiftUI

struct SectionStack: View {
    let selection: AppTab

    var body: some View {
        ZStack {
            ForEach(AppTab.allCases, id: \.self) { section in
                let isActive = section == selection
                AppSectionView(section: section)
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(isActive)
                    .accessibilityHidden(!isActive)
            }
        }
    }
}
