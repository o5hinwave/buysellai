import UIKit

enum MarketplaceSelectionFeedback {
    static let impactStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light

    static func perform(_ action: () -> Void) {
        Haptics.impact(impactStyle)
        action()
    }
}
