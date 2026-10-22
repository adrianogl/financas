import Foundation
import Supabase

@MainActor
final class SupabaseCardService: CardService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func load(since: CalendarDay) async throws(IncomeError) -> CardSnapshot {
        do {
            async let connections: [CardConnection] = client.from(CardConstants.connectionsTable).select().execute().value
            async let accounts: [CardAccount] = client.from(CardConstants.accountsTable).select().execute().value
            async let recurrences: [CardRecurrence] = client.from(CardConstants.recurrencesTable).select().execute().value
            async let transactions = loadTransactions(since: since)
            return try await CardSnapshot(
                connections: connections,
                accounts: accounts,
                transactions: transactions,
                recurrences: recurrences
            )
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func save(_ recurrence: CardRecurrence) async throws(IncomeError) {
        do {
            try await client.from(CardConstants.recurrencesTable)
                .upsert(recurrence, onConflict: "card_account_id,merchant_key", returning: .minimal)
                .execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func rename(accountID: UUID, nickname: String) async throws(IncomeError) {
        do {
            try await client.from(CardConstants.accountsTable)
                .update(["nickname": nickname], returning: .minimal)
                .eq("id", value: accountID.uuidString)
                .execute()
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func sync() async throws(IncomeError) {
        do {
            try await client.functions.invoke(CardConstants.syncFunction)
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func connectToken(itemID: String?) async throws(IncomeError) -> String {
        do {
            let response: ConnectTokenResponse = try await client.functions.invoke(
                CardConstants.connectFunction,
                options: FunctionInvokeOptions(body: ConnectBody(action: "token", itemId: itemID))
            )
            return response.accessToken
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func register(itemID: String) async throws(IncomeError) {
        do {
            try await client.functions.invoke(
                CardConstants.connectFunction,
                options: FunctionInvokeOptions(body: ConnectBody(action: "register", itemId: itemID))
            )
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    func remove(connectionID: UUID) async throws(IncomeError) {
        do {
            try await client.functions.invoke(
                CardConstants.connectFunction,
                options: FunctionInvokeOptions(body: RemoveBody(action: "remove", connectionId: connectionID.uuidString))
            )
        } catch {
            throw SupabaseIncomeService.incomeError(from: error)
        }
    }

    nonisolated private func loadTransactions(since: CalendarDay) async throws -> [CardTransaction] {
        return try await CardPaging.fetchAll(pageSize: CardConstants.pageSize) { from, to in
            try await client.from(CardConstants.transactionsTable)
                .select()
                .gte("date", value: since.text)
                .order("date")
                .order("id")
                .range(from: from, to: to)
                .execute()
                .value
        }
    }

    private struct ConnectBody: Encodable {
        let action: String
        let itemId: String?
    }

    private struct RemoveBody: Encodable {
        let action: String
        let connectionId: String
    }

    private struct ConnectTokenResponse: Decodable {
        let accessToken: String
    }
}
