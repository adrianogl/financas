import Foundation

enum CardOverlap {
    static func installment(for suggestion: SpendingSuggestion, in transactions: [CardTransaction]) -> CardTransaction? {
        let day = suggestion.spentOn
        return transactions
            .filter { transaction in
                guard transaction.type == .debit,
                      let total = transaction.totalInstallments, total >= 2,
                      let purchaseDate = transaction.purchaseDate,
                      abs(purchaseDate.days(until: day)) <= SuggestionConstants.installmentDayTolerance else { return false }
                let difference = abs(transaction.amount * Decimal(total) - suggestion.amount)
                return difference <= SuggestionConstants.installmentAmountTolerance * Decimal(total)
            }
            .min { ($0.installmentNumber ?? 0, $0.date) < ($1.installmentNumber ?? 0, $1.date) }
    }
}
