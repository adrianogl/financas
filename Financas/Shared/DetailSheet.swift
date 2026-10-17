import SwiftUI

struct DetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let route: DetailRoute

    var body: some View {
        NavigationStack {
            DetailRouteView(route: route)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fechar", systemImage: "xmark") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
