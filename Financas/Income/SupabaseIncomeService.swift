import Foundation
import Supabase

@MainActor
final class SupabaseIncomeService: IncomeService {
    nonisolated static let encoder = JSONEncoder()
    nonisolated static let decoder = JSONDecoder()

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func load() async throws(IncomeError) -> IncomeSnapshot {
        do {
            async let incomes: [Income] = client.from(IncomeConstants.incomesTable).select().execute().value
            async let amounts: [IncomeAmount] = client.from(IncomeConstants.amountsTable).select().execute().value
            async let receipts: [IncomeReceipt] = client.from(IncomeConstants.receiptsTable).select().execute().value
            return try await IncomeSnapshot(incomes: incomes, amounts: amounts, receipts: receipts)
        } catch {
            throw Self.incomeError(from: error)
        }
    }

    func save(_ income: Income, amount: IncomeAmount?) async throws(IncomeError) {
        do {
            try await client.from(IncomeConstants.incomesTable).upsert(income, returning: .minimal).execute()
            if let amount {
                try await client.from(IncomeConstants.amountsTable)
                    .upsert(amount, onConflict: "income_id,valid_from", returning: .minimal)
                    .execute()
            }
        } catch {
            throw Self.incomeError(from: error)
        }
    }

    func delete(incomeID: UUID) async throws(IncomeError) {
        do {
            try await client.from(IncomeConstants.incomesTable).delete().eq("id", value: incomeID.uuidString).execute()
        } catch {
            throw Self.incomeError(from: error)
        }
    }

    func save(_ receipt: IncomeReceipt) async throws(IncomeError) {
        do {
            try await client.from(IncomeConstants.receiptsTable)
                .upsert(receipt, onConflict: "income_id,month", returning: .minimal)
                .execute()
        } catch {
            throw Self.incomeError(from: error)
        }
    }

    func deleteReceipt(id: UUID) async throws(IncomeError) {
        do {
            try await client.from(IncomeConstants.receiptsTable).delete().eq("id", value: id.uuidString).execute()
        } catch {
            throw Self.incomeError(from: error)
        }
    }

    nonisolated static func incomeError(from error: any Error) -> IncomeError {
        error is URLError ? .network : .unknown
    }
}
