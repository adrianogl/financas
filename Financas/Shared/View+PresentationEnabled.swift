import SwiftUI

extension View {
    func presentationEnabled() -> some View {
        environment(\.isEnabled, true)
    }
}
