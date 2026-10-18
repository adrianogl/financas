import SwiftUI

extension View {
    func selectedRowBackground(_ isSelected: Bool) -> some View {
        padding(.horizontal, DetailConstants.selectedRowInset)
            .background(
                isSelected ? Theme.accent.opacity(DetailConstants.selectedRowOpacity) : .clear,
                in: .rect(cornerRadius: DetailConstants.selectedRowCornerRadius)
            )
            .padding(.horizontal, -DetailConstants.selectedRowInset)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
