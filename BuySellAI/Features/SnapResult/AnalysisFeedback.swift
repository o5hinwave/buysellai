import UIKit

enum AnalysisFeedback {
    static let successNotificationType: UINotificationFeedbackGenerator.FeedbackType = .success
    static let failureNotificationType: UINotificationFeedbackGenerator.FeedbackType = .error

    static func performSuccess() {
        Haptics.notify(successNotificationType)
    }

    static func performFailure() {
        Haptics.notify(failureNotificationType)
    }
}
