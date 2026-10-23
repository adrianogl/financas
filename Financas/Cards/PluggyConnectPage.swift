import Foundation

enum PluggyConnectPage {
    static func html(token: String, itemID: String?) -> String {
        let updateItem = itemID.map { "updateItem: \(literal($0))," } ?? ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>html, body { margin: 0; height: 100%; background: transparent; }</style>
        </head>
        <body>
        <script src="\(CardConstants.pluggyConnectScript)"></script>
        <script>
        const send = (event, itemId) => window.webkit.messageHandlers.\(CardConstants.pluggyMessageHandler).postMessage({ event: event, itemId: itemId || null });
        try {
          new PluggyConnect({
            connectToken: \(literal(token)),
            connectorIds: [\(CardConstants.meuPluggyConnectorID)],
            \(updateItem)
            onSuccess: (data) => send("success", data && data.item && data.item.id),
            onError: () => send("error"),
            onClose: () => send("close")
          }).init();
        } catch (e) {
          send("error");
        }
        </script>
        </body>
        </html>
        """
    }

    private static func literal(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else { return "\"\"" }
        return text
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "&", with: "\\u0026")
    }
}
