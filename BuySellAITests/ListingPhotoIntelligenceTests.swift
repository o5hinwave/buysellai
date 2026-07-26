import XCTest
@testable import BuySellAI

final class ListingPhotoIntelligenceTests: XCTestCase {
    func testRecommendedPackageExcludesReferencePhotosFromListingExports() {
        let cover = photo(
            role: .fullItem,
            source: .camera,
            verifies: ["whole item"],
            quality: ListingPhotoQuality(sharpness: 16, lighting: 15, productVisibility: 18)
        )
        let reference = photo(
            role: .referenceOnly,
            source: .internetReference,
            isListingSafe: false,
            quality: ListingPhotoQuality(sharpness: 20, lighting: 20, productVisibility: 20)
        )

        let package = ListingPhotoIntelligence.recommendedPackage(
            for: .ebay,
            candidates: [reference, cover]
        )

        XCTAssertEqual(package.recommendedListingPhotos.map(\.id), [cover.id])
        XCTAssertEqual(package.excludedReferencePhotos.map(\.id), [reference.id])
        XCTAssertEqual(package.utilityByPhotoID[reference.id]?.misleadingRisk, 100)
    }

    func testDuplicateFingerprintReceivesUtilityPenalty() {
        let first = photo(
            role: .fullItem,
            source: .camera,
            dateAdded: Date(timeIntervalSince1970: 1),
            visualFingerprint: "front-view"
        )
        let duplicate = photo(
            role: .alternateAngle,
            source: .camera,
            dateAdded: Date(timeIntervalSince1970: 2),
            visualFingerprint: "front-view"
        )

        let package = ListingPhotoIntelligence.recommendedPackage(
            for: .ebay,
            candidates: [first, duplicate],
            maximumCount: 2
        )

        XCTAssertEqual(package.utilityByPhotoID[first.id]?.duplicationPenalty, 0)
        XCTAssertEqual(package.utilityByPhotoID[duplicate.id]?.duplicationPenalty, 28)
        XCTAssertLessThan(
            package.utilityByPhotoID[duplicate.id]?.total ?? 0,
            package.utilityByPhotoID[first.id]?.total ?? 0
        )
    }

    func testLocalMarketplaceRewardsMeasurementAndConditionDisclosure() {
        let measurement = photo(role: .measurement, source: .camera)
        let packaging = photo(role: .packaging, source: .camera)
        let flaw = photo(role: .flaw, source: .camera)

        let measurementUtility = ListingPhotoIntelligence.utility(for: measurement, marketplace: .facebook)
        let packagingUtility = ListingPhotoIntelligence.utility(for: packaging, marketplace: .facebook)
        let flawUtility = ListingPhotoIntelligence.utility(for: flaw, marketplace: .facebook)

        XCTAssertGreaterThan(measurementUtility.marketplaceRelevance, packagingUtility.marketplaceRelevance)
        XCTAssertGreaterThan(flawUtility.conditionDisclosure, measurementUtility.conditionDisclosure)
    }

    func testUnlinkedAIEnhancedPhotoIsPenalizedAsMisleadingRisk() {
        let enhancedWithoutOriginal = photo(
            role: .enhancedCover,
            source: .aiEnhanced,
            isAIEdited: true,
            relatedOriginalID: nil
        )
        let originalID = UUID()
        let enhancedWithOriginal = photo(
            role: .enhancedCover,
            source: .aiEnhanced,
            isAIEdited: true,
            relatedOriginalID: originalID
        )

        XCTAssertEqual(
            ListingPhotoIntelligence.utility(for: enhancedWithoutOriginal, marketplace: .poshmark).misleadingRisk,
            44
        )
        XCTAssertEqual(
            ListingPhotoIntelligence.utility(for: enhancedWithOriginal, marketplace: .poshmark).misleadingRisk,
            0
        )
    }

    func testEnhancementPlanBuildsSafetyPromptForUserOwnedPhoto() throws {
        let item = DetectedItem(
            name: "Vintage brass lamp",
            category: .home,
            condition: .fair,
            priceEstimate: Decimal(45)
        )
        let source = photo(
            role: .fullItem,
            source: .camera,
            verifies: ["brass base", "visible cord", "scratch on shade"],
            quality: ListingPhotoQuality(
                sharpness: 9,
                lighting: 7,
                productVisibility: 15,
                blurPenalty: 4,
                clutterPenalty: 6
            )
        )

        let plan = try XCTUnwrap(
            ListingPhotoIntelligence.enhancementPlan(
                for: source,
                item: item,
                marketplace: .facebook,
                confirmedFacts: ["maker mark under base", "serial LMP-72"],
                visibleConditionNotes: ["scratch on shade", "aged brass patina"],
                qualityProblems: ["dark photo", "busy background"]
            )
        )

        XCTAssertEqual(plan.sourcePhotoID, source.id)
        XCTAssertEqual(plan.relatedOriginalID, source.id)
        XCTAssertEqual(plan.outputSource, .aiEnhanced)
        XCTAssertTrue(plan.outputIsAIEdited)
        XCTAssertTrue(plan.outputIsListingSafe)
        XCTAssertEqual(plan.targetRole, .enhancedCover)
        XCTAssertTrue(plan.prompt.contains("Vintage brass lamp"))
        XCTAssertTrue(plan.prompt.contains("Facebook"))
        XCTAssertTrue(plan.prompt.contains("dark photo"))
        XCTAssertTrue(plan.prompt.contains("busy background"))
        XCTAssertTrue(plan.prompt.contains("scratch on shade"))
        XCTAssertTrue(plan.prompt.contains("serial LMP-72"))
        XCTAssertTrue(plan.prompt.contains("Preserve the exact product, shape, color, materials, proportions, labels, serial marks, included parts, wear, damage, and condition."))
        XCTAssertTrue(plan.prompt.contains("Preserve visible defects"))
        XCTAssertTrue(plan.prompt.contains("Do not change colors, materials, logos, labels, serial numbers"))
        XCTAssertTrue(plan.prompt.contains("Do not invent accessories"))
        XCTAssertTrue(plan.prompt.contains("Do not make a used item appear new"))
        XCTAssertTrue(plan.prompt.contains("Do not generate a different item."))
    }

    func testEnhancementPlanRejectsReferenceAndAlreadyEditedPhotos() {
        let item = DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        let reference = photo(
            role: .referenceOnly,
            source: .internetReference,
            isListingSafe: false
        )
        let alreadyEdited = photo(
            role: .enhancedCover,
            source: .aiEnhanced,
            isAIEdited: true,
            relatedOriginalID: UUID()
        )

        XCTAssertNil(ListingPhotoIntelligence.enhancementPlan(for: reference, item: item, marketplace: .ebay))
        XCTAssertNil(ListingPhotoIntelligence.enhancementPlan(for: alreadyEdited, item: item, marketplace: .ebay))
    }

    private func photo(
        role: ListingPhotoRole,
        source: ListingPhotoSource,
        dateAdded: Date = Date(timeIntervalSince1970: 1),
        verifies: [String] = [],
        isListingSafe: Bool = true,
        isAIEdited: Bool = false,
        relatedOriginalID: UUID? = nil,
        quality: ListingPhotoQuality = ListingPhotoQuality(sharpness: 12, lighting: 12, productVisibility: 12),
        visualFingerprint: String? = nil
    ) -> ListingPhotoCandidate {
        ListingPhotoCandidate(
            imageData: Data([0x01, 0x02, 0x03]),
            role: role,
            source: source,
            dateAdded: dateAdded,
            verifies: verifies,
            isListingSafe: isListingSafe,
            isAIEdited: isAIEdited,
            relatedOriginalID: relatedOriginalID,
            quality: quality,
            visualFingerprint: visualFingerprint
        )
    }
}
