import Foundation

enum AppStoreLinks {
    private static let supportSiteBase = "https://buysell-ai-support.o5hinwavve.chatgpt.site"

    static let supportURLString = "\(supportSiteBase)/support"
    static let privacyPolicyURLString = "\(supportSiteBase)/privacy"
    static let termsURLString = "\(supportSiteBase)/terms"

    enum Destination {
        case support
        case privacyPolicy
        case terms

        var urlString: String {
            switch self {
            case .support:
                AppStoreLinks.supportURLString
            case .privacyPolicy:
                AppStoreLinks.privacyPolicyURLString
            case .terms:
                AppStoreLinks.termsURLString
            }
        }
    }

    static func url(for destination: Destination) -> URL? {
        URL(string: destination.urlString)
    }
}
