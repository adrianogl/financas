import UIKit

enum DeviceIdentity {
    @MainActor
    static func current(defaults: UserDefaults = .standard) -> SuggestionDevice {
        SuggestionDevice(id: UIDevice.current.identifierForVendor ?? stored(in: defaults), name: UIDevice.current.model)
    }

    private static func stored(in defaults: UserDefaults) -> UUID {
        if let text = defaults.string(forKey: SuggestionConstants.deviceIDKey), let id = UUID(uuidString: text) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: SuggestionConstants.deviceIDKey)
        return id
    }
}
