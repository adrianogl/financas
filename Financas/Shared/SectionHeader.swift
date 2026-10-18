import SwiftUI

struct SectionHeader: View {
    let title: String
    let add: SectionAddAction?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
            Spacer(minLength: 8)
            if let add {
                Button(add.title, systemImage: "plus", action: add.action)
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
            }
        }
        .frame(minHeight: LayoutConstants.sectionHeaderMinHeight)
    }
}
