import SwiftUI

struct IncomeIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(tint, in: .circle)
    }
}
