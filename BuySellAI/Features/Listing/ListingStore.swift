import Observation
import Foundation

@MainActor
@Observable
final class ListingStore {
    typealias GenerateHandler = (DetectedItem, Marketplace, String?) async throws -> String

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

    private let generateHandler: GenerateHandler
    private var generation = 0

    init(
        item: DetectedItem,
        marketplace: Marketplace,
        existingListingText: String?,
        generateHandler: @escaping GenerateHandler = { item, marketplace, accessToken in
            try await APIClient.shared.generateListing(
                item: item,
                marketplace: marketplace,
                accessToken: accessToken
            )
        }
    ) {
        self.item = item
        self.marketplace = marketplace
        self.generateHandler = generateHandler
        if let existingListingText {
            self.listingText = existingListingText
            self.phase = .success
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
                  ProcessInfo.processInfo.arguments.contains("--ui-testing-generate-offline") == false {
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
        generation += 1
        let currentGeneration = generation
        phase = .loading
        do {
            let generatedText = try await generateHandler(item, marketplace, accessToken)
            guard currentGeneration == generation else { return }
            guard generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw APIError.decoding
            }
            listingText = generatedText
            phase = .success
        } catch is CancellationError {
            guard currentGeneration == generation else { return }
            phase = .failed(APIError.unknown.localizedDescription)
        } catch {
            guard currentGeneration == generation else { return }
            phase = .failed(APIError.userMessage(for: error))
        }
    }
}
