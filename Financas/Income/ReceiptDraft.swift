import Foundation

struct ReceiptDraft: Equatable {
    var workedDays: Int?
    var workedHours: Decimal?
    let hoursPerDay: Decimal?
    let hourlyRate: Decimal?
    var receivedOn: CalendarDay
    var amount: Decimal
    private let fixedExpected: Decimal

    init(occurrence: IncomeOccurrence, today: CalendarDay) {
        let hoursPerDay = occurrence.income.hoursPerDay
        self.hoursPerDay = hoursPerDay
        hourlyRate = occurrence.hourlyRate
        fixedExpected = occurrence.expectedAmount

        if let receipt = occurrence.receipt {
            workedDays = receipt.workedDays
            workedHours = receipt.workedHours
            receivedOn = receipt.receivedOn
            amount = receipt.amount
        } else {
            workedDays = occurrence.businessDays
            workedHours = occurrence.businessDays.flatMap { days in hoursPerDay.map { Decimal(days) * $0 } }
            receivedOn = today
            amount = occurrence.expectedAmount
        }
    }

    var expectedAmount: Decimal {
        guard let workedHours, let hourlyRate else { return fixedExpected }
        return workedHours * hourlyRate
    }

    mutating func setWorkedDays(_ days: Int) {
        workedDays = days
        guard let hoursPerDay else { return }
        setWorkedHours(Decimal(days) * hoursPerDay)
    }

    mutating func setWorkedHours(_ hours: Decimal) {
        workedHours = hours
        amount = expectedAmount
    }

    func receipt(for occurrence: IncomeOccurrence) -> IncomeReceipt {
        IncomeReceipt(
            id: occurrence.receipt?.id ?? UUID(),
            incomeID: occurrence.income.id,
            month: occurrence.month,
            receivedOn: receivedOn,
            amount: amount,
            workedDays: workedDays,
            workedHours: workedHours
        )
    }
}
