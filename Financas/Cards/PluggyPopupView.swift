import UIKit
import WebKit

final class PluggyPopupView: UIView {
    let webView: WKWebView

    init(configuration: WKWebViewConfiguration, uiDelegate: WKUIDelegate, onClose: @escaping (PluggyPopupView) -> Void) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        webView.uiDelegate = uiDelegate

        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.title = "Fechar"
        let close = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            onClose(self)
        })
        close.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(close)
        addSubview(webView)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            webView.topAnchor.constraint(equalTo: close.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
