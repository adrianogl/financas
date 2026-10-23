import SwiftUI
import WebKit

struct PluggyConnectView: UIViewRepresentable {
    let token: String
    let itemID: String?
    let onEvent: (PluggyConnectEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: CardConstants.pluggyMessageHandler)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.uiDelegate = context.coordinator
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        context.coordinator.container = container
        context.coordinator.mainWebView = webView
        webView.loadHTMLString(
            PluggyConnectPage.html(token: token, itemID: itemID),
            baseURL: URL(string: CardConstants.pluggyConnectBaseURL)
        )
        return container
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.mainWebView?.configuration.userContentController.removeScriptMessageHandler(forName: CardConstants.pluggyMessageHandler)
        coordinator.closeAllPopups()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate {
        var onEvent: (PluggyConnectEvent) -> Void
        weak var container: UIView?
        weak var mainWebView: WKWebView?
        private var popups: [ObjectIdentifier: PluggyPopupView] = [:]

        init(onEvent: @escaping (PluggyConnectEvent) -> Void) {
            self.onEvent = onEvent
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let event = PluggyConnectEvent.parse(message.body) else { return }
            onEvent(event)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let container else { return nil }
            let popup = PluggyPopupView(configuration: configuration, uiDelegate: self) { [weak self] closed in
                self?.remove(closed)
            }
            popup.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(popup)
            NSLayoutConstraint.activate([
                popup.topAnchor.constraint(equalTo: container.topAnchor),
                popup.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                popup.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                popup.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            popups[ObjectIdentifier(popup.webView)] = popup
            return popup.webView
        }

        func webViewDidClose(_ webView: WKWebView) {
            guard let popup = popups[ObjectIdentifier(webView)] else { return }
            remove(popup)
        }

        func closeAllPopups() {
            Array(popups.values).forEach(remove)
        }

        private func remove(_ popup: PluggyPopupView) {
            popups[ObjectIdentifier(popup.webView)] = nil
            popup.removeFromSuperview()
        }
    }
}
