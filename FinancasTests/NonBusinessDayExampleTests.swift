import Testing
@testable import Financas

struct NonBusinessDayExampleTests {
    @Test func exampleTexts() {
        #expect(NonBusinessDayExample.text(rule: .next) == "Dia 1 de novembro de 2026 é domingo e cai em 3 de novembro.")
        #expect(NonBusinessDayExample.text(rule: .previous) == "Dia 1 de novembro de 2026 é domingo e cai em 30 de outubro.")
        #expect(NonBusinessDayExample.text(rule: .keep) == "Dia 1 de novembro de 2026 é domingo e fica nesse dia.")
    }
}
