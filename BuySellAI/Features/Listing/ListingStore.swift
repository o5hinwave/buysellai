import Observation
import Foundation

@MainActor
@Observable
final class ListingStore {
    typealias GenerateHandler = (
        DetectedItem,
        Marketplace,
        ItemDetailAnswers?,
        MarketplaceComparison?,
        AnalyzeIdentificationProfile?,
        Data?,
        String?
    ) async throws -> GeneratedListing

    enum Phase: Equatable {
        case idle
        case loading
        case success
        case failed(String)
    }

    let item: DetectedItem
    let marketplace: Marketplace
    let details: ItemDetailAnswers?
    let marketplaceComparison: MarketplaceComparison?
    let identificationProfile: AnalyzeIdentificationProfile?
    let imageData: Data?
    var listingText: String
    var draft: GeneratedListingDraft?
    var entitlementSnapshot: EntitlementSnapshot?
    var phase: Phase

    private let generateHandler: GenerateHandler
    private var generation = 0

    init(
        item: DetectedItem,
        marketplace: Marketplace,
        details: ItemDetailAnswers? = nil,
        marketplaceComparison: MarketplaceComparison? = nil,
        identificationProfile: AnalyzeIdentificationProfile? = nil,
        imageData: Data? = nil,
        existingListingText: String?,
        existingListingDraft: GeneratedListingDraft? = nil,
        generateHandler: @escaping GenerateHandler = { item, marketplace, details, marketplaceComparison, identificationProfile, imageData, accessToken in
            try await APIClient.shared.generateListingPayload(
                item: item,
                marketplace: marketplace,
                details: details,
                marketplaceComparison: marketplaceComparison,
                identificationProfile: identificationProfile,
                imageData: imageData,
                accessToken: accessToken
            )
        }
    ) {
        self.item = item
        self.marketplace = marketplace
        self.details = details?.sanitizedForUse
        self.marketplaceComparison = marketplaceComparison?.sanitizedForDisplay()
        self.identificationProfile = identificationProfile?.sanitizedForDisplay()
        self.imageData = imageData
        self.generateHandler = generateHandler
        if let existingListingText {
            if let safeListingText = try? ListingTextContract.validatedStored(existingListingText) {
                self.listingText = safeListingText
                self.draft = existingListingDraft?.sanitizedForMarketplace(marketplace, item: item)
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
            let generated = try await generateHandler(item, marketplace, details, marketplaceComparison, identificationProfile, imageData, accessToken)
            guard currentGeneration == generation else { return }
            listingText = try ListingTextContract.validatedGenerated(generated.listing)
            draft = generated.draft?.sanitizedForMarketplace(marketplace, item: item)
            entitlementSnapshot = generated.entitlement
            phase = .success
            ProductAnalytics.recordEstimatedCost(
                event: .listingGenerated,
                endpoint: "generate-listing",
                estimatedAICostCents: Decimal(string: "0.18") ?? 0,
                groundedSearchCount: generated.draft?.evidenceSources?.count ?? 0,
                extra: [
                    "marketplace": marketplace.rawValue,
                    "category": item.category.rawValue,
                    "has_structured_draft": generated.draft == nil ? "false" : "true"
                ].merging(generated.entitlement?.analyticsProperties ?? [:]) { current, _ in current }
            )
        } catch let error where APIError.isCancellation(error) {
            guard currentGeneration == generation else { return }
            phase = .idle
        } catch {
            guard currentGeneration == generation else { return }
            ProductAnalytics.recordFailure(
                .listingGenerationFailed,
                endpoint: "generate-listing",
                error: error,
                extra: [
                    "marketplace": marketplace.rawValue,
                    "category": item.category.rawValue,
                    "has_marketplace_comparison": marketplaceComparison == nil ? "false" : "true",
                    "has_answers": details == nil ? "false" : "true"
                ]
            )
            draft = nil
            phase = .failed(APIError.userMessage(for: error))
        }
    }
}
