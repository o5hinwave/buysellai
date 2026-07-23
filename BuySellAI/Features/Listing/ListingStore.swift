import Observation
import Foundation

@MainActor
@Observable
final class ListingStore {
    typealias GenerateHandler = (DetectedItem, Marketplace, String?) async throws -> GeneratedListing

    enum Phase: Equatable {
        case idle
        case loading
        case success
        case failed(String)
    }

    let item: DetectedItem
    let marketplace: Marketplace
    var listingText: String
    var draft: GeneratedListingDraft?
    var phase: Phase

    private let generateHandler: GenerateHandler
    private var generation = 0

    init(
        item: DetectedItem,
        marketplace: Marketplace,
        existingListingText: String?,
        generateHandler: @escaping GenerateHandler = { item, marketplace, accessToken in
            try await APIClient.shared.generateListingPayload(
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
            if let safeListingText = try? ListingTextContract.validatedStored(existingListingText) {
                self.listingText = safeListingText
                self.draft = nil
                self.phase = .success
            } else {
                self.listingText = ""
                self.draft = nil
                self.phase = .failed(APIError.decoding.localizedDescription)
            }
        } else {
#if DEBUG
            if LaunchArguments.isUITesting,
               LaunchArguments.contains(LaunchArguments.uiTestingGenerateOffline) == false {
                self.listingText = ListingFixtureText.sample(for: item, marketplace: marketplace)
                self.draft = nil
                self.phase = .success
            } else {
                self.listingText = ""
                self.draft = nil
                self.phase = .idle
            }
#else
            self.listingText = ""
            self.draft = nil
            self.phase = .idle
#endif
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
            let generated = try await generateHandler(item, marketplace, accessToken)
            guard currentGeneration == generation else { return }
            listingText = try ListingTextContract.validatedGenerated(generated.listing)
            draft = generated.draft
            phase = .success
        } catch let error where APIError.isCancellation(error) {
            guard currentGeneration == generation else { return }
            phase = .idle
        } catch {
            guard currentGeneration == generation else { return }
            draft = nil
            phase = .failed(APIError.userMessage(for: error))
        }
    }
}
