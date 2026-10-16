import SwiftUI
import UIKit

enum Theme {
    static let accent = Color.accentColor
    static let positive = Color.dynamic(light: 0x2E8B6E, dark: 0x5CC79E)
    static let background = Color.dynamic(light: 0xFAFBFD, dark: 0x0B0F1A)
    static let blobPrimary = Color.dynamic(light: 0xC9D8FF, dark: 0x1D2D5C)
    static let blobSecondary = Color.dynamic(light: 0xE3D9FA, dark: 0x2A2152)
    static let blobTertiary = Color.dynamic(light: 0xD6E3FF, dark: 0x172A50)
    static let markTop = Color.dynamic(light: 0xEAF0FF, dark: 0x22325E)
    static let markBottom = Color.dynamic(light: 0xC9D8FF, dark: 0x16224A)
    static let categoryTints: [Color] = [
        .dynamic(light: 0x7FA1EE, dark: 0x7FA1EE),
        .dynamic(light: 0x9AA7C2, dark: 0x7C88A6),
        .dynamic(light: 0xB79BE6, dark: 0x9C7FD6),
    ]
}

extension Color {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
