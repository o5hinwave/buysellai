import UIKit

enum HistoryDeletionFeedback {
    static let notificationType: UINotificationFeedbackGenerator.FeedbackType = .warning

    static func perform() {
        Haptics.notify(notificationType)
    }
}
