import Foundation

enum SpendingIntentError: Error, CustomLocalizedStringResourceConvertible {
    case unavailable
    case noSpendings
    case invalidAmount
    case saveFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unavailable: "\(SpendingIntentConstants.unavailableMessage)"
        case .noSpendings: "\(SpendingIntentConstants.noSpendingsMessage)"
        case .invalidAmount: "\(SpendingIntentConstants.invalidAmountMessage)"
        case .saveFailed(let message): "\(message.isEmpty ? SpendingIntentConstants.saveFailedMessage : message)"
        }
    }
}
