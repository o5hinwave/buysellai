import XCTest

@testable import BuySellAI

final class AppStoreLinksTests: XCTestCase {
    func testLegalAndSupportLinksUsePreparedSupportSiteRoutes() throws {
        let expected = [
            AppStoreLinks.supportURLString: "/support",
            AppStoreLinks.privacyPolicyURLString: "/privacy",
            AppStoreLinks.termsURLString: "/terms"
        ]

        for (urlString, path) in expected {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "buysell-ai-support.o5hinwavve.chatgpt.site")
            XCTAssertEqual(url.path, path)
        }
    }

    func testSettingsDestinationsResolveToPublicReadyHttpsURLs() throws {
        let destinations: [AppStoreLinks.Destination] = [.support, .privacyPolicy, .terms]

        for destination in destinations {
            let url = try XCTUnwrap(AppStoreLinks.url(for: destination))
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "buysell-ai-support.o5hinwavve.chatgpt.site")
        }
    }
}
