import XCTest
@testable import BuySellAI

final class ModelFormattingTests: XCTestCase {
    func testCategoryDisplayIsLocalizedButAPIValueStaysBackendStable() {
        XCTAssertEqual(Category.home.display, "Home")
        XCTAssertEqual(Category.home.apiValue, "Home")
        XCTAssertEqual(
            Category.allCases.map(\.apiValue),
            [
                "Electronics", "Furniture", "Clothing", "Shoes", "Bags", "Jewelry",
                "Toys", "Kids", "Home", "Tools", "Sports", "Books", "Media", "Music",
                "Collectibles", "Art", "Other"
            ]
        )
        XCTAssertEqual(Category(apiValue: "Home"), .home)
        XCTAssertEqual(Category(apiValue: "home"), .home)
        XCTAssertEqual(Category(apiValue: "Collectibles"), .collectibles)
        XCTAssertEqual(Category.knownAPIValue("Home"), .home)
        XCTAssertEqual(Category.knownAPIValue("home"), .home)
        XCTAssertEqual(Category.knownAPIValue("collectibles"), .collectibles)
        XCTAssertNil(Category.knownAPIValue("Pets"))
        XCTAssertEqual(Category(apiValue: "Pets"), .other)
    }

    func testConditionDisplayIsLocalizedButAPIValueStaysBackendStable() {
        XCTAssertEqual(Condition.likeNew.display, "Like New")
        XCTAssertEqual(Condition.likeNew.apiValue, "likeNew")
        XCTAssertEqual(Condition.good.display, "Good")
        XCTAssertEqual(Condition.good.apiValue, "good")
        XCTAssertEqual(Condition(apiValue: "Like New"), .likeNew)
        XCTAssertEqual(Condition(apiValue: "for_parts"), .forParts)
        XCTAssertEqual(Condition.knownAPIValue("Like New"), .likeNew)
        XCTAssertEqual(Condition.knownAPIValue("for_parts"), .forParts)
        XCTAssertNil(Condition.knownAPIValue("broken"))
        XCTAssertEqual(Condition(apiValue: "broken"), .good)
    }

    func testNativeScanEvidenceFindsHighValueModelAndSerialText() {
        let candidates = NativeScanEvidence.modelOrSerialCandidates(from: [
            "Made in Mexico",
            "Model A2482",
            "S/N C02ABC12345",
            "Style CW2288-111",
            "Plain words only"
        ])

        XCTAssertEqual(candidates, [
            "Model A2482",
            "S/N C02ABC12345",
            "Style CW2288-111"
        ])

        let evidence = NativeScanEvidence(
            recognizedText: [" Model A2482 ", " ", "Model A2482"],
            barcodes: [NativeScanBarcode(payload: " 012345678905 ", symbology: " ean13 ")],
            modelOrSerialCandidates: candidates
        )

        XCTAssertEqual(evidence.sanitizedForPayload?.recognizedText, ["Model A2482"])
        XCTAssertEqual(evidence.sanitizedForPayload?.barcodes.first?.payload, "012345678905")
        XCTAssertEqual(evidence.sanitizedForPayload?.barcodes.first?.symbology, "ean13")
    }

    func testThemePreferenceDisplayIsLocalizedAndRawValuesStayPersistent() {
        XCTAssertEqual(ThemePreference.system.display, "System")
        XCTAssertEqual(ThemePreference.light.display, "Light")
        XCTAssertEqual(ThemePreference.dark.display, "Dark")
        XCTAssertEqual(ThemePreference.allCases.map(\.rawValue), ["system", "light", "dark"])
    }

    func testDecimalCurrencyFormattingAvoidsDoublePrecisionLoss() throws {
        let value = try XCTUnwrap(Decimal(string: "9007199254740993"))

        XCTAssertEqual(
            value.currency(),
            value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        )
        XCTAssertNotEqual(
            value.currency(),
            value.doubleValue.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        )
    }

    func testDecimalCurrencyFormattingSupportsFractionDigits() throws {
        let value = try XCTUnwrap(Decimal(string: "45.5"))

        XCTAssertEqual(
            value.currency(fractionLength: 2),
            value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
        )
    }

    func testItemDetailAnswersRememberHandledUnknownsWithoutBoostingFactQuality() throws {
        var answers = ItemDetailAnswers()

        answers.markAnswered(.labelOrBrand)
        answers.markAnswered(.largeOrFragile)

        let sanitized = try XCTUnwrap(answers.sanitizedForUse)
        XCTAssertTrue(sanitized.hasAnsweredOrSkipped(.labelOrBrand))
        XCTAssertTrue(sanitized.hasAnsweredOrSkipped(.largeOrFragile))
        XCTAssertFalse(sanitized.hasListingPayloadDetails)
        XCTAssertEqual(sanitized.marketplaceFactQualityBonus, 0)
        XCTAssertEqual(sanitized.displayValues, ["Brand: I don't know", "Large or fragile: No"])

        answers.labelOrBrand = "Stiffel"
        answers.clearAnswered(.labelOrBrand)

        let confirmed = try XCTUnwrap(answers.sanitizedForUse)
        XCTAssertTrue(confirmed.hasListingPayloadDetails)
        XCTAssertEqual(confirmed.marketplaceFactQualityBonus, 4)
        XCTAssertEqual(confirmed.displayValues, ["Brand: Stiffel", "Large or fragile: No"])
    }

    func testItemDetailAnswersSeedHighConfidenceAnalysisFactsWithoutAskingAgain() throws {
        let analysis = AnalyzeIntelligence(
            itemFacts: [
                AnalyzeItemFact(label: "Brand", value: "Nike", confidence: 0.91),
                AnalyzeItemFact(label: "Style code", value: "CW2288-111", confidence: 0.84),
                AnalyzeItemFact(label: "Original box", value: "Included", confidence: 0.8),
                AnalyzeItemFact(label: "Possible color", value: "Red", confidence: 0.62)
            ],
            missingFacts: ["size"],
            photoPrompt: nil
        )

        let seeded = ItemDetailAnswers()
            .seedingConfirmedAnalysisFacts(from: analysis, category: .shoes)

        XCTAssertEqual(seeded.labelOrBrand, "Brand: Nike")
        XCTAssertEqual(seeded.sizeOrModel, "Style code: CW2288-111")
        XCTAssertEqual(seeded.included, "Original box: Included")
        XCTAssertTrue(seeded.hasAnsweredOrSkipped(ItemDetailFieldKey.labelOrBrand))
        XCTAssertTrue(seeded.hasAnsweredOrSkipped(ItemDetailFieldKey.sizeOrModel))
        XCTAssertTrue(seeded.hasAnsweredOrSkipped(ItemDetailFieldKey.included))
        XCTAssertFalse(seeded.extraDetails.contains("Red"))
        XCTAssertEqual(seeded.marketplaceFactQualityBonus, 12)
    }

    func testItemDetailAnswersAppendAnalysisFactsWithoutReplacingUserAnswers() throws {
        let analysis = AnalyzeIntelligence(
            itemFacts: [
                AnalyzeItemFact(label: "Brand", value: "Sony", confidence: 0.88),
                AnalyzeItemFact(label: "Model", value: "WH-1000XM5", confidence: 0.86),
                AnalyzeItemFact(label: "Condition", value: "Light wear", confidence: 0.82)
            ],
            missingFacts: [],
            photoPrompt: nil
        )

        let seeded = ItemDetailAnswers(labelOrBrand: "User typed brand")
            .seedingConfirmedAnalysisFacts(from: analysis, category: .electronics)

        XCTAssertEqual(seeded.labelOrBrand, "User typed brand")
        XCTAssertEqual(seeded.sizeOrModel, "Model: WH-1000XM5")
        XCTAssertEqual(seeded.flaws, "Condition: Light wear")
        XCTAssertTrue(seeded.hasAnsweredOrSkipped(ItemDetailFieldKey.labelOrBrand))
        XCTAssertTrue(seeded.hasAnsweredOrSkipped(ItemDetailFieldKey.flaws))
    }

    func testItemDetailAnswersKeepMarketplaceNotesSeparate() throws {
        var answers = ItemDetailAnswers(extraDetails: "Brass finish")

        answers.setMarketplaceNote("Prefer fixed price", for: .ebay)
        answers.markMarketplaceAnswered(.facebook)

        let sanitized = try XCTUnwrap(answers.sanitizedForUse)
        XCTAssertEqual(sanitized.extraDetails, "Brass finish")
        XCTAssertEqual(sanitized.marketplaceNote(for: .ebay), "Prefer fixed price")
        XCTAssertTrue(sanitized.hasMarketplaceNoteOrSkipped(.ebay))
        XCTAssertTrue(sanitized.hasMarketplaceNoteOrSkipped(.facebook))
        XCTAssertFalse(sanitized.hasMarketplaceNoteOrSkipped(.poshmark))
        XCTAssertEqual(sanitized.marketplaceFactQualityBonus, 8)
        XCTAssertEqual(
            sanitized.displayValues,
            [
                "Other: Brass finish",
                "eBay: Prefer fixed price",
                "Facebook: I don't know"
            ]
        )
    }

    func testItemDetailAnswersRememberHandledMarketplaceUnknownsWithoutBoostingFactQuality() throws {
        var answers = ItemDetailAnswers()

        answers.markMarketplaceAnswered(.facebook)

        let sanitized = try XCTUnwrap(answers.sanitizedForUse)
        XCTAssertTrue(sanitized.hasMarketplaceNoteOrSkipped(.facebook))
        XCTAssertFalse(sanitized.hasListingPayloadDetails)
        XCTAssertEqual(sanitized.marketplaceFactQualityBonus, 0)
        XCTAssertEqual(sanitized.displayValues, ["Facebook: I don't know"])
    }

    func testItemDetailAnswersDecodeOldPayloadWithoutMarketplaceNotes() throws {
        let data = Data(
            """
            {
              "labelOrBrand": "Stiffel",
              "sizeOrModel": "",
              "flaws": "",
              "included": "",
              "extraDetails": "",
              "isLargeOrFragile": false,
              "answeredFieldKeys": ["labelOrBrand"]
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(ItemDetailAnswers.self, from: data)
        XCTAssertEqual(decoded.labelOrBrand, "Stiffel")
        XCTAssertTrue(decoded.marketplaceNotes.isEmpty)
        XCTAssertTrue(decoded.answeredMarketplaces.isEmpty)
    }

    func testItemDetailAnswersRoundTripMarketplaceNotes() throws {
        let answers = ItemDetailAnswers(
            marketplaceNotes: [.ebay: "Prefer fixed price", .facebook: "Can deliver nearby"],
            answeredMarketplaces: [.ebay, .facebook]
        )

        let data = try JSONEncoder().encode(answers)
        let decoded = try JSONDecoder().decode(ItemDetailAnswers.self, from: data)

        XCTAssertEqual(decoded.marketplaceNote(for: .ebay), "Prefer fixed price")
        XCTAssertEqual(decoded.marketplaceNote(for: .facebook), "Can deliver nearby")
        XCTAssertTrue(decoded.hasMarketplaceNoteOrSkipped(.ebay))
        XCTAssertTrue(decoded.hasMarketplaceNoteOrSkipped(.facebook))
    }

    func testListingPhotoPackageExportsOnlyUserOwnedListingPhotos() throws {
        let item = DetectedItem(
            name: "Nintendo Switch OLED",
            category: .electronics,
            condition: .good,
            priceEstimate: 180
        )
        let package = ListingPhotoPackage.makeForListing(
            item: item,
            marketplace: .ebay,
            originalImageData: Data([1, 2, 3]),
            referenceImageURL: "https://example.com/reference.jpg"
        )

        XCTAssertEqual(package.listingReadyPhotos.count, 1)
        XCTAssertEqual(package.recommendedListingPhotos.count, 1)
        XCTAssertTrue(package.hasReferenceOnlyImage)
        XCTAssertEqual(package.statusTitle, "Your photo is ready")
        XCTAssertEqual(package.recommendation, "Add one label or model photo for a stronger listing.")
        XCTAssertEqual(
            package.listingReadyPhotos[0].exportFileName(for: item, index: 1),
            "Nintendo-Switch-OLED-01-Cover.jpg"
        )
    }

    func testListingPhotoPackageDoesNotExportMissingOrReferencePhotos() throws {
        let item = DetectedItem(
            name: "  ",
            category: .home,
            condition: .fair,
            priceEstimate: 25
        )
        let package = ListingPhotoPackage.makeForListing(
            item: item,
            marketplace: .facebook,
            originalImageData: nil,
            referenceImageURL: "https://example.com/reference.jpg"
        )

        XCTAssertTrue(package.listingReadyPhotos.isEmpty)
        XCTAssertTrue(package.recommendedListingPhotos.isEmpty)
        XCTAssertTrue(package.hasReferenceOnlyImage)
        XCTAssertEqual(package.statusTitle, "No listing photos ready")
        XCTAssertEqual(package.recommendation, "Reference image stays out. Add a real item photo before posting.")
    }

    func testTargetedScansBecomeSupplementalListingPhotosForCurrentItem() throws {
        let itemID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let otherItemID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let item = DetectedItem(
            id: itemID,
            name: "Nintendo Switch OLED",
            category: .electronics,
            condition: .good,
            priceEstimate: 180
        )
        let otherItem = DetectedItem(
            id: otherItemID,
            name: "Other Switch",
            category: .electronics,
            condition: .good,
            priceEstimate: 120
        )
        let originalData = Data([1, 2, 3])
        let labelData = Data([4, 5, 6])
        let conditionData = Data([7, 8, 9])
        let wrongItemData = Data([10, 11, 12])
        let labelPhoto = try XCTUnwrap(
            ItemPhotoAsset.targetedScan(
                item: item,
                imageData: labelData,
                request: TargetedScanRequest(
                    prompt: "Scan the barcode",
                    benefit: "This can confirm the exact model.",
                    role: .barcode
                )
            )
        )
        let conditionPhoto = try XCTUnwrap(
            ItemPhotoAsset.targetedScan(
                item: item,
                imageData: conditionData,
                request: TargetedScanRequest(
                    prompt: "Show the damaged area",
                    benefit: "Buyers will want to see this.",
                    role: .condition
                )
            )
        )
        let wrongItemPhoto = try XCTUnwrap(
            ItemPhotoAsset.targetedScan(
                item: otherItem,
                imageData: wrongItemData,
                request: TargetedScanRequest(
                    prompt: "Show everything included",
                    benefit: "This may improve your price estimate.",
                    role: .accessories
                )
            )
        )

        let package = ListingPhotoPackage.makeForListing(
            item: item,
            marketplace: .ebay,
            originalImageData: originalData,
            supplementalPhotos: [conditionPhoto, wrongItemPhoto, labelPhoto],
            referenceImageURL: nil
        )

        XCTAssertEqual(package.listingReadyPhotos.map(\.role), [.cover, .label, .condition])
        XCTAssertEqual(package.listingReadyPhotos.map(\.imageData), [originalData, labelData, conditionData])
        XCTAssertEqual(package.exportFiles(for: item).map(\.fileName), [
            "Nintendo-Switch-OLED-01-Cover.jpg",
            "Nintendo-Switch-OLED-02-Label.jpg",
            "Nintendo-Switch-OLED-03-Condition.jpg"
        ])
    }

    func testListingPhotoPackageCanExportAllListingReadyPhotosBeyondRecommendedSet() throws {
        let item = DetectedItem(
            name: "Oak Cabinet",
            category: .furniture,
            condition: .good,
            priceEstimate: 160
        )
        let package = ListingPhotoPackage(
            itemID: item.id,
            marketplace: .facebook,
            photos: [
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([1]),
                    source: .camera,
                    role: .cover,
                    dateAdded: Date(timeIntervalSince1970: 1),
                    verifies: "Front view",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([2]),
                    source: .camera,
                    role: .label,
                    dateAdded: Date(timeIntervalSince1970: 2),
                    verifies: "Maker label",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([3]),
                    source: .camera,
                    role: .included,
                    dateAdded: Date(timeIntervalSince1970: 3),
                    verifies: "Shelf pins",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([4]),
                    source: .camera,
                    role: .condition,
                    dateAdded: Date(timeIntervalSince1970: 4),
                    verifies: "Small scratch",
                    isListingSafe: true
                )
            ],
            excludedReferenceImageURL: nil
        )

        XCTAssertEqual(package.exportFiles(for: item).map(\.role), [.cover, .condition])
        XCTAssertEqual(package.exportFiles(for: item, scope: .allListingReady).map(\.role), [.cover, .label, .included, .condition])
        XCTAssertEqual(package.exportFiles(for: item, scope: .allListingReady).map(\.fileName), [
            "Oak-Cabinet-01-Cover.jpg",
            "Oak-Cabinet-02-Label.jpg",
            "Oak-Cabinet-03-Included.jpg",
            "Oak-Cabinet-04-Condition.jpg"
        ])
    }

    func testTargetedScanEvidenceFillsMatchingDetailAndPhotoVerification() throws {
        let item = DetectedItem(
            name: "Nintendo Switch OLED",
            category: .electronics,
            condition: .good,
            priceEstimate: 180
        )
        let evidence = NativeScanEvidence(
            recognizedText: ["HEG-001", "Nintendo"],
            barcodes: [NativeScanBarcode(payload: "045496883386", symbology: "VNBarcodeSymbologyEAN13")],
            modelOrSerialCandidates: ["Model HEG-001"]
        )
        let request = TargetedScanRequest(
            prompt: "Scan the barcode",
            benefit: "This can confirm the exact model.",
            role: .barcode
        )
        var answers = ItemDetailAnswers()

        answers.applyTargetedScanEvidence(evidence, request: request)
        let photo = try XCTUnwrap(
            ItemPhotoAsset.targetedScan(
                item: item,
                imageData: Data([4, 5, 6]),
                request: request,
                evidence: evidence
            )
        )

        XCTAssertEqual(answers.sizeOrModel, "Barcode 045496883386")
        XCTAssertTrue(answers.hasAnsweredOrSkipped(.targetedScan))
        XCTAssertTrue(answers.hasAnsweredOrSkipped(.sizeOrModel))
        XCTAssertEqual(photo.role, .label)
        XCTAssertEqual(photo.verifies, "Barcode: 045496883386")
    }

    func testAnalyzeIntelligenceAppliesTargetedScanEvidenceAsVisibleFact() throws {
        let analysis = AnalyzeIntelligence(
            itemFacts: [AnalyzeItemFact(label: "Material", value: "Plastic", confidence: 0.72)],
            missingFacts: ["model number", "condition"],
            photoPrompt: "Scan the model label"
        )
        let evidence = NativeScanEvidence(
            recognizedText: ["Nintendo HEG-001", "Made in China"],
            barcodes: [],
            modelOrSerialCandidates: ["Model HEG-001"]
        )
        let request = TargetedScanRequest(
            prompt: "Scan the model label",
            benefit: "This can confirm the exact model.",
            role: .label
        )

        let updated = analysis.applyingTargetedScanEvidence(evidence, request: request)

        XCTAssertEqual(updated.itemFacts.first, AnalyzeItemFact(label: "Scanned detail", value: "Model HEG-001", confidence: 0.95))
        XCTAssertEqual(updated.itemFacts.dropFirst().first, AnalyzeItemFact(label: "Material", value: "Plastic", confidence: 0.72))
        XCTAssertEqual(updated.missingFacts, ["condition"])
    }

    func testAnalyzeIntelligenceAppliesBarcodeEvidenceAndKeepsUnansweredMissingFacts() throws {
        let analysis = AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: ["barcode", "included accessories"],
            photoPrompt: "Scan the barcode"
        )
        let evidence = NativeScanEvidence(
            recognizedText: [],
            barcodes: [NativeScanBarcode(payload: "045496883386", symbology: "ean13")],
            modelOrSerialCandidates: []
        )
        let request = TargetedScanRequest(
            prompt: "Scan the barcode",
            benefit: "This can confirm the exact model.",
            role: .barcode
        )

        let updated = analysis.applyingTargetedScanEvidence(evidence, request: request)

        XCTAssertEqual(updated.itemFacts.first, AnalyzeItemFact(label: "Scanned barcode", value: "045496883386", confidence: 0.95))
        XCTAssertEqual(updated.missingFacts, ["included accessories"])
    }

    func testMarketplacePhotoScanPlaybookAsksAfterGenericScanWasSkipped() throws {
        let item = DetectedItem(
            name: "Nintendo Switch OLED",
            category: .electronics,
            condition: .good,
            priceEstimate: 180
        )
        var answers = ItemDetailAnswers()
        answers.markAnswered(.targetedScan)

        let request = try XCTUnwrap(
            MarketplacePhotoScanPlaybook.targetedScanRequest(
                for: .ebay,
                item: item,
                answers: answers,
                supplementalPhotos: []
            )
        )

        XCTAssertEqual(request.title, "Scan the model label")
        XCTAssertEqual(request.role, .label)
        XCTAssertFalse(answers.hasAnsweredOrSkipped(.marketplaceTargetedScan))
    }

    func testMarketplacePhotoScanPlaybookStopsAfterMatchingPhotoExists() throws {
        let item = DetectedItem(
            name: "Nintendo Switch OLED",
            category: .electronics,
            condition: .good,
            priceEstimate: 180
        )
        let labelPhoto = ItemPhotoAsset(
            itemID: item.id,
            imageData: Data([1, 2, 3]),
            source: .camera,
            role: .label,
            verifies: "Model HEG-001",
            isListingSafe: true
        )

        let request = MarketplacePhotoScanPlaybook.targetedScanRequest(
            for: .ebay,
            item: item,
            answers: ItemDetailAnswers(),
            supplementalPhotos: [labelPhoto]
        )

        XCTAssertNil(request)
    }

    func testListingPhotoPackageRanksCurrentItemPhotosAndRejectsExactDuplicates() throws {
        let itemID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let otherItemID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let item = DetectedItem(
            id: itemID,
            name: "Nintendo Switch OLED",
            category: .electronics,
            condition: .good,
            priceEstimate: 180
        )
        let coverData = Data([1, 2, 3, 4])
        let labelData = Data([5, 6, 7, 8])
        let package = ListingPhotoPackage(
            itemID: item.id,
            marketplace: .ebay,
            photos: [
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: labelData,
                    source: .camera,
                    role: .label,
                    dateAdded: Date(timeIntervalSince1970: 20),
                    verifies: "Model label and serial pattern",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: coverData,
                    source: .photoLibrary,
                    role: .cover,
                    dateAdded: Date(timeIntervalSince1970: 10),
                    verifies: "Front cover photo",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: coverData,
                    source: .photoLibrary,
                    role: .fullItem,
                    dateAdded: Date(timeIntervalSince1970: 30),
                    verifies: "Duplicate full item photo",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: otherItemID,
                    imageData: Data([9, 9, 9]),
                    source: .camera,
                    role: .condition,
                    dateAdded: Date(timeIntervalSince1970: 5),
                    verifies: "Wrong item scratch",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([10]),
                    source: .internetReference,
                    role: .reference,
                    dateAdded: Date(timeIntervalSince1970: 1),
                    verifies: "Reference image",
                    isListingSafe: false
                )
            ],
            excludedReferenceImageURL: nil
        )

        XCTAssertEqual(package.listingReadyPhotos.map(\.role), [.cover, .label])
        XCTAssertEqual(package.recommendedListingPhotos.map(\.role), [.cover, .label])
        XCTAssertEqual(package.exportFiles(for: item).map(\.fileName), [
            "Nintendo-Switch-OLED-01-Cover.jpg",
            "Nintendo-Switch-OLED-02-Label.jpg"
        ])
    }

    func testListingPhotoPackageUsesMarketplacePhotoUtilityForDuplicateWinner() throws {
        let item = DetectedItem(
            name: "Oak Cabinet",
            category: .furniture,
            condition: .good,
            priceEstimate: 160
        )
        let duplicateData = Data([3, 2, 1, 0])
        let blurryCover = ItemPhotoAsset(
            itemID: item.id,
            imageData: duplicateData,
            source: .camera,
            role: .cover,
            dateAdded: Date(timeIntervalSince1970: 1),
            verifies: "Blurry front view",
            isListingSafe: true
        )
        let clearCover = ItemPhotoAsset(
            itemID: item.id,
            imageData: duplicateData,
            source: .camera,
            role: .cover,
            dateAdded: Date(timeIntervalSince1970: 2),
            verifies: "Clear full item front view",
            isListingSafe: true
        )
        let measurementPhoto = ItemPhotoAsset(
            itemID: item.id,
            imageData: Data([9, 9, 9]),
            source: .camera,
            role: .condition,
            verifies: "Shows flaw and measurements",
            isListingSafe: true
        )

        let package = ListingPhotoPackage(
            itemID: item.id,
            marketplace: .facebook,
            photos: [blurryCover, clearCover, measurementPhoto],
            excludedReferenceImageURL: nil
        )

        XCTAssertEqual(package.listingReadyPhotos.first?.verifies, "Clear full item front view")
        XCTAssertGreaterThan(
            clearCover.listingPhotoUtilityScore(for: .facebook),
            blurryCover.listingPhotoUtilityScore(for: .facebook)
        )
        XCTAssertGreaterThan(
            measurementPhoto.listingPhotoUtility(for: .facebook).conditionDisclosure,
            clearCover.listingPhotoUtility(for: .facebook).conditionDisclosure
        )
    }

    func testPhotoExportIncludesVerificationWithoutInternetReferenceData() throws {
        let item = DetectedItem(
            name: "Vintage Brass Lamp",
            category: .home,
            condition: .fair,
            priceEstimate: 65
        )
        let package = ListingPhotoPackage(
            itemID: item.id,
            marketplace: .chairish,
            photos: [
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([7, 7, 7]),
                    source: .camera,
                    role: .condition,
                    verifies: "Shows scratch on base",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([8, 8, 8]),
                    source: .internetReference,
                    role: .reference,
                    verifies: "Similar public image",
                    isListingSafe: false
                )
            ],
            excludedReferenceImageURL: "https://example.com/lamp.jpg"
        )

        let export = try XCTUnwrap(package.exportFiles(for: item).first)
        XCTAssertEqual(export.fileName, "Vintage-Brass-Lamp-01-Condition.jpg")
        XCTAssertEqual(export.role, .condition)
        XCTAssertEqual(export.verifies, "Shows scratch on base")
        XCTAssertEqual(export.imageData, Data([7, 7, 7]))
        XCTAssertTrue(package.hasReferenceOnlyImage)
    }

    func testListingPhotoPackageExportsMarketplaceRecommendedSetOnly() throws {
        let item = DetectedItem(
            name: "Leather Jacket",
            category: .clothing,
            condition: .good,
            priceEstimate: 90
        )
        let package = ListingPhotoPackage(
            itemID: item.id,
            marketplace: .poshmark,
            photos: [
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([1]),
                    source: .camera,
                    role: .condition,
                    dateAdded: Date(timeIntervalSince1970: 4),
                    verifies: "Sleeve wear",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([2]),
                    source: .camera,
                    role: .cover,
                    dateAdded: Date(timeIntervalSince1970: 1),
                    verifies: "Front cover",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([3]),
                    source: .camera,
                    role: .label,
                    dateAdded: Date(timeIntervalSince1970: 3),
                    verifies: "Size tag",
                    isListingSafe: true
                ),
                ItemPhotoAsset(
                    itemID: item.id,
                    imageData: Data([4]),
                    source: .camera,
                    role: .included,
                    dateAdded: Date(timeIntervalSince1970: 2),
                    verifies: "Extra hanger photo",
                    isListingSafe: true
                )
            ],
            excludedReferenceImageURL: nil
        )

        XCTAssertEqual(package.listingReadyPhotos.map(\.role), [.cover, .label, .included, .condition])
        XCTAssertEqual(package.recommendedListingPhotos.map(\.role), [.cover, .label, .included, .condition])
        XCTAssertNil(package.missingRecommendedPhotoRole)
        XCTAssertEqual(package.statusTitle, "Your 4 best photos are ready")
        XCTAssertEqual(package.recommendation, "These 4 photos are enough to post.")
        XCTAssertEqual(package.exportFiles(for: item).map(\.fileName), [
            "Leather-Jacket-01-Cover.jpg",
            "Leather-Jacket-02-Label.jpg",
            "Leather-Jacket-03-Included.jpg",
            "Leather-Jacket-04-Condition.jpg"
        ])
    }

    func testGeneratedListingDraftSanitizesTitleForSelectedMarketplaceLimit() throws {
        let item = DetectedItem(
            name: "Oak Dining Table",
            category: .furniture,
            condition: .good,
            priceEstimate: 260
        )
        let draft = GeneratedListingDraft(
            title: "Solid Oak Dining Table With Two Leaves And Six Chairs Excellent Local Pickup Dining Room Set",
            description: "Solid oak dining table in good condition.",
            itemSpecifics: ["Oak", "Dining table"]
        )

        let sanitized = try XCTUnwrap(draft.sanitizedForMarketplace(.chairish, item: item))

        XCTAssertLessThanOrEqual(sanitized.title?.count ?? 0, Marketplace.chairish.optimizationProfile.titleMaxCharacters)
        XCTAssertEqual(sanitized.title, "Solid Oak Dining Table With Two Leaves And Six Chairs Excellent")
    }

    func testGeneratedListingDraftAddsPlainMarketplaceRequiredFieldWarnings() throws {
        let item = DetectedItem(
            name: "iPhone 13",
            category: .electronics,
            condition: .good,
            priceEstimate: 320
        )
        let draft = GeneratedListingDraft(
            title: "iPhone 13 Blue",
            description: "Good condition phone.",
            missingInfoWarnings: ["Confirm visible scratches before posting."]
        )

        let sanitized = try XCTUnwrap(draft.sanitizedForMarketplace(.swappa, item: item))

        XCTAssertEqual(sanitized.missingInfoWarnings, [
            "Confirm visible scratches before posting.",
            "Add carrier, storage, and battery details before posting on Swappa."
        ])
    }

    func testGeneratedListingDraftDoesNotAddRequirementWarningWhenFactsArePresent() throws {
        let item = DetectedItem(
            name: "Nike Dunk Low",
            category: .shoes,
            condition: .good,
            priceEstimate: 90
        )
        let draft = GeneratedListingDraft(
            title: "Nike Dunk Low Size 10",
            description: "Includes original box. Style code shown in photos.",
            itemSpecifics: ["Size 10", "Box included", "Style code visible"]
        )

        let sanitized = try XCTUnwrap(draft.sanitizedForMarketplace(.goat, item: item))

        XCTAssertNil(sanitized.missingInfoWarnings)
    }
}
