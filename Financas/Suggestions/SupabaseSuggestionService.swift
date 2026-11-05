import Foundation
import Supabase

@MainActor
final class SupabaseSuggestionService: SuggestionService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func load(since: Date) async throws(IncomeError) -> SuggestionSnapshot {
        do {
            async let suggestions: [SpendingSuggestion] = client.from(SuggestionConstants.suggestionsTable)
                .select()
                .gte("occurred_at", value: Self.timestamp(since))
                .execute()
                .value
            async let rules: [MerchantSpendingRule] = client.from(SuggestionConstants.rulesTable).select().execute().value
            return try await SuggestionSnapshot(suggestions: suggestions, rules: rules)
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func report(_ purchase: SuggestionPurchase, merchantKey: String, device: SuggestionDevice) async throws(IncomeError) -> SuggestionReport {
        let params = SuggestionRPCParams.Report(
            p_device: device.id,
            p_device_name: device.name,
            p_merchant: purchase.merchant,
            p_merchant_key: merchantKey,
            p_card: purchase.card,
            p_amount: purchase.amount,
            p_occurred_at: Self.timestamp(purchase.occurredAt)
        )
        do {
            return try await client.rpc(SuggestionConstants.reportFunction, params: params).execute().value
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func confirm(id: UUID, expenseID: UUID, spentOn: CalendarDay, autoLaunch: Bool?) async throws(IncomeError) -> SuggestionConfirmation {
        let params = SuggestionRPCParams.Confirm(p_id: id, p_expense_id: expenseID, p_spent_on: spentOn.text, p_auto_launch: autoLaunch)
        do {
            return try await client.rpc(SuggestionConstants.confirmFunction, params: params).execute().value
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func reopen(id: UUID) async throws(IncomeError) -> SpendingSuggestion {
        do {
            return try await client.rpc(SuggestionConstants.reopenFunction, params: SuggestionRPCParams.Reopen(p_id: id)).execute().value
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func move(id: UUID, expenseID: UUID) async throws(IncomeError) -> SpendingSuggestion {
        do {
            return try await client.rpc(SuggestionConstants.moveFunction, params: SuggestionRPCParams.Move(p_id: id, p_expense_id: expenseID))
                .execute()
                .value
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func dismiss(id: UUID) async throws(IncomeError) {
        let change = SuggestionRPCParams.Dismiss(status: SpendingSuggestionStatus.dismissed.rawValue, resolved_at: Self.timestamp(.now))
        do {
            try await client.from(SuggestionConstants.suggestionsTable)
                .update(change, returning: .minimal)
                .eq("id", value: id.uuidString)
                .eq("status", value: SpendingSuggestionStatus.pending.rawValue)
                .execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}
