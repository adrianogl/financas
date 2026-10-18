import Foundation
@testable import Financas

enum ExpenseSamples {
    static func money(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    static func month(_ year: Int, _ month: Int) -> YearMonth {
        YearMonth(year: year, month: month)
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: year, month: month, day: day)
    }

    static let today = day(2026, 10, 17)

    static let luz = Expense(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        name: "Luz",
        startMonth: month(2026, 7)
    )

    static let internet = Expense(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!,
        name: "Internet",
        startMonth: month(2026, 10)
    )

    static let condominio = Expense(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!,
        name: "Condomínio",
        startMonth: month(2026, 10)
    )

    static func term(_ expense: Expense, from: YearMonth, day: Int, estimated: Decimal, averageFrom: YearMonth? = nil) -> ExpenseTerm {
        ExpenseTerm(id: UUID(), expenseID: expense.id, validFrom: from, estimatedAmount: estimated, dayOfMonth: day, averageFrom: averageFrom ?? from)
    }

    static let luzTerm = term(luz, from: month(2026, 7), day: 13, estimated: 180)
    static let internetTerm = term(internet, from: month(2026, 10), day: 26, estimated: 180)
    static let condominioTerm = term(condominio, from: month(2026, 10), day: 10, estimated: 1150)

    static let snapshot = ExpenseSnapshot(
        expenses: [luz, internet, condominio],
        terms: [luzTerm, internetTerm, condominioTerm],
        bills: []
    )

    static func paid(_ expense: Expense, _ month: YearMonth, _ amount: Decimal, on day: CalendarDay) -> ExpenseBill {
        ExpenseBill(id: UUID(), expenseID: expense.id, month: month, billAmount: nil, billDueDate: nil, paidOn: day, paidAmount: amount)
    }

    static func bill(_ expense: Expense, _ month: YearMonth, _ amount: Decimal, due: CalendarDay) -> ExpenseBill {
        ExpenseBill(id: UUID(), expenseID: expense.id, month: month, billAmount: amount, billDueDate: due, paidOn: nil, paidAmount: nil)
    }

    static func part(_ expense: Expense, _ name: String, position: Int) -> ExpensePart {
        ExpensePart(id: UUID(), expenseID: expense.id, name: name, position: position)
    }

    static func partTerm(
        _ part: ExpensePart,
        from: YearMonth,
        amount: Decimal,
        isFixed: Bool = false,
        averageFrom: YearMonth? = nil,
        isActive: Bool = true,
        day: Int? = nil
    ) -> ExpensePartTerm {
        ExpensePartTerm(
            id: UUID(), partID: part.id, validFrom: from, amount: amount, isFixed: isFixed,
            averageFrom: averageFrom ?? from, isActive: isActive, dayOfMonth: day
        )
    }

    static func partBill(
        _ part: ExpensePart,
        _ month: YearMonth,
        bill: Decimal? = nil,
        due: CalendarDay? = nil,
        paid: Decimal? = nil,
        on paidOn: CalendarDay? = nil
    ) -> ExpensePartBill {
        ExpensePartBill(
            id: UUID(), partID: part.id, month: month,
            billAmount: bill, billDueDate: bill == nil ? nil : due ?? month.day(10),
            paidOn: paid == nil ? nil : paidOn ?? month.day(10), paidAmount: paid
        )
    }
}
