import SwiftUI

extension HomeStatCard {
    init(_ stat: HomeStat, action: (() -> Void)? = nil) {
        self.init(
            title: stat.title,
            value: stat.value,
            caption: stat.caption,
            badge: stat.badge,
            tint: stat.isWarning ? Theme.warning : nil,
            action: action
        )
    }
}
