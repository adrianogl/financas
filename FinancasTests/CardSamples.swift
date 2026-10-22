import Foundation
@testable import Financas

enum CardSamples {
    static let today = CalendarDay(year: 2026, month: 10, day: 22)

    static let connection = UUID(uuidString: "00000000-0000-0000-0000-0000000000C0")!

    static let c6 = CardAccount(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C6")!,
        connectionID: connection,
        name: "C6 Carbon",
        lastDigits: "1234",
        nickname: "C6"
    )

    static let caixa = CardAccount(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000CA")!,
        connectionID: connection,
        name: "Caixa Visa",
        lastDigits: "5678",
        nickname: "Caixa"
    )

    static func day(_ y: Int, _ m: Int, _ d: Int) -> CalendarDay {
        CalendarDay(year: y, month: m, day: d)
    }

    static func tx(
        _ account: CardAccount,
        _ y: Int,
        _ m: Int,
        _ d: Int,
        _ amount: Decimal,
        _ description: String,
        installment: (Int, Int)? = nil,
        purchase: CalendarDay? = nil,
        type: CardTransactionType = .debit,
        pending: Bool = false
    ) -> CardTransaction {
        CardTransaction(
            id: UUID().uuidString,
            cardAccountID: account.id,
            date: day(y, m, d),
            description: description,
            amount: amount,
            type: type,
            isPending: pending,
            installmentNumber: installment?.0,
            totalInstallments: installment?.1,
            purchaseDate: purchase
        )
    }
}
