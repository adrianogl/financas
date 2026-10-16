import Foundation
import Testing
@testable import Financas

struct GreetingTests {
    @Test(arguments: [(4, "Boa noite"), (5, "Bom dia"), (11, "Bom dia"), (12, "Boa tarde"), (17, "Boa tarde"), (18, "Boa noite")])
    func greetingFollowsHour(hour: Int, expected: String) {
        #expect(Greeting.forHour(hour) == expected)
    }

    @Test func dateCapitalizesOnlyFirstLetter() {
        let date = Date(timeIntervalSince1970: 1_792_170_000)
        let text = Greeting.dateText(for: date, locale: Locale(identifier: "pt_BR"))

        #expect(text.first?.isUppercase == true)
        #expect(text.contains("de outubro"))
    }

    @Test func includesNameWhenPresent() {
        #expect(Greeting.text(hour: 15, name: "Adriano") == "Boa tarde, Adriano")
        #expect(Greeting.text(hour: 15, name: "") == "Boa tarde")
    }
}
