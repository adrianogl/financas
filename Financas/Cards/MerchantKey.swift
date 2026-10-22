import Foundation

enum MerchantKey {
    private static let installmentSuffix = try! NSRegularExpression(
        pattern: #"\b(PARC(ELA)?\s*)?\d{1,2}\s*/\s*\d{1,2}\b"#,
        options: [.caseInsensitive]
    )
    private static let separators = try! NSRegularExpression(pattern: #"[^\p{L}\p{N}]+"#)

    static func make(_ description: String) -> String {
        let folded = description
            .folding(options: .diacriticInsensitive, locale: nil)
            .uppercased()
        let words = replace(separators, in: replace(installmentSuffix, in: folded, with: " "), with: " ")
        return words.trimmingCharacters(in: .whitespaces)
    }

    static func stripInstallment(_ description: String) -> String {
        replace(installmentSuffix, in: description, with: "")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    private static func replace(_ regex: NSRegularExpression, in text: String, with template: String) -> String {
        regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
