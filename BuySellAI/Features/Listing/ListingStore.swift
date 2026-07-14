import Observation
import Foundation

@MainActor
@Observable
final class ListingStore {
    enum Phase: Equatable {
        case idle
        case loading
        case success
        case failed(String)
    }

    let item: DetectedItem
    let marketplace: Marketplace
    var listingText: String
    var phase: Phase

    init(item: DetectedItem, marketplace: Marketplace, existingListingText: String?) {
        self.item = item
        self.marketplace = marketplace
        if let existingListingText {
            self.listingText = existingListingText
            self.phase = .success
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            self.listingText = """
            TITLE:
            \(item.name) - \(item.condition.display)

            DESCRIPTION:
            Selling a \(item.name.lowercased()) in \(item.condition.display.lowercased()) condition. Asking \(item.priceEstimate.currency(code: item.currencyCode)).
            """
            self.phase = .success
        } else {
            self.listingText = ""
            self.phase = .idle
        }
    }

    func generateIfNeeded(accessToken: String?) async {
        guard phase == .idle else { return }
        await generate(accessToken: accessToken)
    }

    func generate(accessToken: String?) async {
        phase = .loading
        do {
            listingText = try await APIClient.shared.generateListing(
                item: item,
                marketplace: marketplace,
                accessToken: accessToken
            )
            phase = .success
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
