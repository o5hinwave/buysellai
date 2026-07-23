import Foundation

struct ReviewPromptGate {
    private let defaults: UserDefaults
    private let key = "lastReviewPromptVersion"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func canRequestReview(for version: String) -> Bool {
        defaults.string(forKey: key) != version
    }

    func markReviewRequested(for version: String) {
        defaults.set(version, forKey: key)
    }
}
