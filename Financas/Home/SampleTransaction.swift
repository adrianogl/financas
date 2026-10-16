import Foundation

struct SampleTransaction: Identifiable {
    let name: String
    let category: String
    let dateLabel: String
    let amount: Decimal
    let systemImage: String
    let tintIndex: Int

    var id: String { name }
    var isIncome: Bool { amount > 0 }
}
