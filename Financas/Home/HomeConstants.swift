import Foundation

enum HomeConstants {
    static let currencyCode = "BRL"
    static let sampleBalance = Decimal(321_456) / 100
    static let sampleMonthLabel = "Saldo de outubro"
    static let balanceFloor = 1_000.0
    static let balanceCeiling = 3_600.0

    static let balancePoints: [BalancePoint] = [
        BalancePoint(day: 1, balance: 1_480),
        BalancePoint(day: 4, balance: 1_620),
        BalancePoint(day: 5, balance: 2_950),
        BalancePoint(day: 8, balance: 2_710),
        BalancePoint(day: 10, balance: 2_520),
        BalancePoint(day: 12, balance: 2_640),
        BalancePoint(day: 14, balance: 3_080),
        BalancePoint(day: 16, balance: 3_214.56),
    ]

    static let sampleTransactions: [SampleTransaction] = [
        SampleTransaction(name: "Salário", category: "Receita", dateLabel: "05 out", amount: 8_500, systemImage: "arrow.down", tintIndex: -1),
        SampleTransaction(name: "Pão de Açúcar", category: "Mercado", dateLabel: "ontem", amount: Decimal(-28_740) / 100, systemImage: "cart", tintIndex: 0),
        SampleTransaction(name: "Uber", category: "Transporte", dateLabel: "hoje", amount: Decimal(-2_390) / 100, systemImage: "car", tintIndex: 1),
        SampleTransaction(name: "Netflix", category: "Assinaturas", dateLabel: "12 out", amount: Decimal(-4_490) / 100, systemImage: "play.rectangle", tintIndex: 2),
    ]
}
