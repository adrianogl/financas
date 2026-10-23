import SwiftUI
import WebKit

struct PluggyConnectView: UIViewRepresentable {
    let token: String
    let itemID: String?
    let onEvent: (PluggyConnectEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: CardConstants.pluggyMessageHandler)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.loadHTMLString(
            PluggyConnectPage.html(token: token, itemID: itemID),
            baseURL: URL(string: CardConstants.pluggyConnectBaseURL)
        )
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: CardConstants.pluggyMessageHandler)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onEvent: (PluggyConnectEvent) -> Void

        init(onEvent: @escaping (PluggyConnectEvent) -> Void) {
            self.onEvent = onEvent
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let event = PluggyConnectEvent.parse(message.body) else { return }
            onEvent(event)
        }
    }
}
