import Foundation

enum SuggestionRPCParams {
    struct Report: Encodable, Sendable {
        let p_device: UUID
        let p_device_name: String
        let p_merchant: String
        let p_merchant_key: String
        let p_card: String
        let p_amount: Decimal
        let p_occurred_at: String
    }

    struct Confirm: Encodable, Sendable {
        let p_id: UUID
        let p_expense_id: UUID
        let p_spent_on: String
        let p_auto_launch: Bool?
    }

    struct Reopen: Encodable, Sendable {
        let p_id: UUID
    }

    struct Move: Encodable, Sendable {
        let p_id: UUID
        let p_expense_id: UUID
    }

    struct Dismiss: Encodable, Sendable {
        let status: String
        let resolved_at: String
    }
}
