import SwiftUI

struct PluggyConnectSheet: View {
    let request: PluggyConnectRequest
    let onEvent: (PluggyConnectEvent) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PluggyConnectView(token: request.token, itemID: request.itemID) { event in
                dismiss()
                onEvent(event)
            }
            .ignoresSafeArea(edges: .bottom)
            .background(AppBackground())
            .navigationTitle("Conectar banco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
