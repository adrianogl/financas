import Foundation

enum Greeting {
    static func dateText(for date: Date, locale: Locale = .current) -> String {
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
        return text.prefix(1).uppercased(with: locale) + text.dropFirst()
    }

    static func forHour(_ hour: Int) -> String {
        switch hour {
        case 5..<12:
            "Bom dia"
        case 12..<18:
            "Boa tarde"
        default:
            "Boa noite"
        }
    }

    static func text(hour: Int, name: String) -> String {
        let greeting = forHour(hour)
        return name.isEmpty ? greeting : "\(greeting), \(name)"
    }
}
