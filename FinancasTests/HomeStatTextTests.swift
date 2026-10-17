import Foundation
import Testing
@testable import Financas

struct HomeStatTextTests {
    @Test func expectedCaptionShowsPlannedAmount() {
        #expect(HomeStatText.expected(10400) == "de R$\u{00A0}10.400,00")
    }

    @Test func overdueBadgeHidesZeroAndPluralizes() {
        #expect(HomeStatText.overdueBadge(0) == nil)
        #expect(HomeStatText.overdueBadge(1) == "1 atrasada")
        #expect(HomeStatText.overdueBadge(3) == "3 atrasadas")
    }

    @Test func overdueNamesKeepsAtMostTwo() {
        #expect(HomeStatText.overdueNames(["Freela site", "Gás", "Luz"]) == "Freela site · Gás")
        #expect(HomeStatText.overdueNames(["Gás"]) == "Gás")
    }

    @Test func overdueNamesSkipsRepeatedNames() {
        #expect(HomeStatText.overdueNames(["Gás", "Gás", "Luz"]) == "Gás · Luz")
    }

    @Test func overdueNamesWhenNothingIsLate() {
        #expect(HomeStatText.overdueNames([]) == "Nada atrasado")
    }

    @Test func balanceCaptionNamesTheMonth() {
        #expect(HomeStatText.balanceCaption(YearMonth(year: 2026, month: 10)) == "recebido menos pago em outubro")
    }
}
