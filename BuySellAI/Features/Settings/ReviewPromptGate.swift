import Foundation

struct ReviewPromptGate {
    private let defaults: UserDefaults
    private let key = "lastReviewPromptVersion"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func shouldRequestReview(for version: String) -> Bool {
        guard defaults.string(forKey: key) != version else {
            return false
        }
        defaults.set(version, forKey: key)
        return true
    }
}
