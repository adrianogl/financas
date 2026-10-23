import Foundation

enum PostgresTimestamp {
    static func date(from text: String) -> Date? {
        let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let withoutFraction = Date.ISO8601FormatStyle()
        return (try? withFraction.parse(text)) ?? (try? withoutFraction.parse(text))
    }
}
