import Foundation
import Supabase

@MainActor
final class SupabaseExpenseService: ExpenseService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func load() async throws(IncomeError) -> ExpenseSnapshot {
        do {
            async let expenses: [Expense] = client.from(ExpenseConstants.expensesTable).select().execute().value
            async let terms: [ExpenseTerm] = client.from(ExpenseConstants.termsTable).select().execute().value
            async let bills: [ExpenseBill] = client.from(ExpenseConstants.billsTable).select().execute().value
            async let parts: [ExpensePart] = client.from(ExpenseConstants.partsTable).select().execute().value
            async let partTerms: [ExpensePartTerm] = client.from(ExpenseConstants.partTermsTable).select().execute().value
            async let entries: [ExpenseEntry] = client.from(ExpenseConstants.entriesTable).select().execute().value
            async let partBills: [ExpensePartBill] = client.from(ExpenseConstants.partBillsTable).select().execute().value
            return try await ExpenseSnapshot(
                expenses: expenses,
                terms: terms,
                bills: bills,
                parts: parts,
                partTerms: partTerms,
                entries: entries,
                partBills: partBills
            )
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func save(
        _ expense: Expense,
        term: ExpenseTerm?,
        parts: [ExpensePart],
        partTerms: [ExpensePartTerm]
    ) async throws(IncomeError) {
        do {
            try await client.from(ExpenseConstants.expensesTable).upsert(expense, returning: .minimal).execute()
            if let term {
                try await client.from(ExpenseConstants.termsTable)
                    .upsert(term, onConflict: "expense_id,valid_from", returning: .minimal)
                    .execute()
            }
            if !parts.isEmpty {
                try await client.from(ExpenseConstants.partsTable)
                    .upsert(parts, onConflict: "id", returning: .minimal)
                    .execute()
            }
            if !partTerms.isEmpty {
                try await client.from(ExpenseConstants.partTermsTable)
                    .upsert(partTerms, onConflict: "part_id,valid_from", returning: .minimal)
                    .execute()
            }
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func delete(expenseID: UUID) async throws(IncomeError) {
        do {
            try await client.from(ExpenseConstants.expensesTable).delete().eq("id", value: expenseID.uuidString).execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func save(_ bill: ExpenseBill) async throws(IncomeError) {
        do {
            try await client.from(ExpenseConstants.billsTable)
                .upsert(bill, onConflict: "expense_id,month", returning: .minimal)
                .execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func deleteBill(id: UUID) async throws(IncomeError) {
        do {
            try await client.from(ExpenseConstants.billsTable).delete().eq("id", value: id.uuidString).execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func save(_ partBills: [ExpensePartBill]) async throws(IncomeError) {
        guard !partBills.isEmpty else { return }
        do {
            try await client.from(ExpenseConstants.partBillsTable)
                .upsert(partBills, onConflict: "part_id,month", returning: .minimal)
                .execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func deletePartBills(ids: [UUID]) async throws(IncomeError) {
        guard !ids.isEmpty else { return }
        do {
            try await client.from(ExpenseConstants.partBillsTable)
                .delete()
                .in("id", values: ids.map(\.uuidString))
                .execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func save(_ entry: ExpenseEntry) async throws(IncomeError) {
        do {
            try await client.from(ExpenseConstants.entriesTable).upsert(entry, returning: .minimal).execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func deleteEntry(id: UUID) async throws(IncomeError) {
        do {
            try await client.from(ExpenseConstants.entriesTable).delete().eq("id", value: id.uuidString).execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }
}
