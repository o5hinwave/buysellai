import Foundation
import UIKit
import XCTest
@testable import BuySellAI

final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testAnalyzeBuildsSupabaseFunctionRequest() async throws {
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/analyze-image")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            Self.assertDeviceIDHeader(in: request)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let imageDataURL = try XCTUnwrap(json["imageDataUrl"] as? String)
            XCTAssertTrue(imageDataURL.hasPrefix("data:image/jpeg;base64,"))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"  Mug  ","category":"Home","condition":"good","currentPrice":12}"#.utf8))
        }

        let response = try await client.analyze(image: Data([1, 2, 3]), accessToken: "access-token")

        XCTAssertEqual(response.name, "Mug")
        XCTAssertEqual(response.category, "Home")
        XCTAssertEqual(response.condition, "good")
        XCTAssertEqual(response.currentPrice, Decimal(12))
    }

    func testAnalyzeCompactsCameraSizedJPEGBeforeUpload() async throws {
        let fullSizeJPEG = try Self.makeJPEG(width: 2_600, height: 1_900)
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let imageDataURL = try XCTUnwrap(json["imageDataUrl"] as? String)
            let base64 = String(imageDataURL.dropFirst("data:image/jpeg;base64,".count))
            let uploaded = try XCTUnwrap(Data(base64Encoded: base64))
            let uploadedImage = try XCTUnwrap(UIImage(data: uploaded))

            XCTAssertLessThan(uploaded.count, fullSizeJPEG.count)
            XCTAssertLessThanOrEqual(max(uploadedImage.size.width, uploadedImage.size.height), 1_280)

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Camera","category":"Electronics","condition":"good","currentPrice":50}"#.utf8))
        }

        _ = try await client.analyze(image: fullSizeJPEG, accessToken: nil)
    }

    func testAnalyzeIncludesNativeScanEvidenceWhenAvailable() async throws {
        let evidence = NativeScanEvidence(
            recognizedText: [" MODEL A2482 ", "Serial SN12345"],
            barcodes: [
                NativeScanBarcode(payload: " 012345678905 ", symbology: "VNBarcodeSymbologyEAN13")
            ],
            modelOrSerialCandidates: ["MODEL A2482", "Serial SN12345"],
            photoQuality: PhotoQualityAssessment(
                brightness: 0.12,
                contrast: 0.2,
                glareRatio: 0.01,
                width: 640,
                height: 480,
                issue: .tooDark
            )
        )
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let scanEvidence = try XCTUnwrap(json["nativeScanEvidence"] as? [String: Any])
            XCTAssertEqual(scanEvidence["recognizedText"] as? [String], ["MODEL A2482", "Serial SN12345"])
            let barcodes = try XCTUnwrap(scanEvidence["barcodes"] as? [[String: Any]])
            XCTAssertEqual(barcodes.first?["payload"] as? String, "012345678905")
            XCTAssertEqual(barcodes.first?["symbology"] as? String, "VNBarcodeSymbologyEAN13")
            XCTAssertEqual(scanEvidence["modelOrSerialCandidates"] as? [String], ["MODEL A2482", "Serial SN12345"])
            let photoQuality = try XCTUnwrap(scanEvidence["photoQuality"] as? [String: Any])
            XCTAssertEqual(photoQuality["issue"] as? String, "tooDark")
            XCTAssertEqual(photoQuality["width"] as? Int, 640)
            XCTAssertEqual(photoQuality["height"] as? Int, 480)

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Phone","category":"Electronics","condition":"good","currentPrice":250}"#.utf8))
        }

        let response = try await client.analyze(
            image: Data([1, 2, 3]),
            nativeScanEvidence: evidence
        )

        XCTAssertEqual(response.name, "Phone")
        XCTAssertEqual(response.category, "Electronics")
    }

    func testAnalyzeIgnoresWebOnlyFollowUpAndTaxFields() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "name": "Ceramic mug",
                  "category": "Home",
                  "condition": "good",
                  "currentPrice": 9,
                  "followUpQuestions": ["Is it deductible?"],
                  "isDeductible": true,
                  "taxCategory": "household"
                }
                """.utf8
            ))
        }

        let response = try await client.analyze(image: Data([1, 2, 3]))

        XCTAssertEqual(response.name, "Ceramic mug")
        XCTAssertEqual(response.category, "Home")
        XCTAssertEqual(response.condition, "good")
        XCTAssertEqual(response.currentPrice, Decimal(9))
    }

    func testAnalyzeReturnsSanitizedListingIntelligenceHints() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "name": "Ceramic mug",
                  "category": "Home",
                  "condition": "good",
                  "currentPrice": 9,
                  "analysis": {
                    "itemFacts": [
                      { "label": " Material ", "value": " Ceramic ", "confidence": 1.4 },
                      { "label": " ", "value": "Ignored", "confidence": 0.7 }
                    ],
                    "missingFacts": [" maker ", ""],
                    "photoPrompt": " Show the bottom mark. ",
                    "likelyMatches": [
                      {
                        "name": "  Ceramic mug with maker mark  ",
                        "distinguishingQuestion": " Is there a stamp on the bottom? ",
                        "confidence": 1.3
                      },
                      {
                        "name": " ",
                        "distinguishingQuestion": "Ignored",
                        "confidence": 0.6
                      }
                    ],
                    "referenceImages": [
                      {
                        "title": "  Similar ceramic mug  ",
                        "url": " https://example.com/mug.jpg ",
                        "source": "  Visual search  "
                      },
                      {
                        "title": "Invalid URL",
                        "url": "file:///tmp/mug.jpg",
                        "source": "Ignored"
                      }
                    ],
                    "identificationProfile": {
                      "confirmedFacts": [" Material: Ceramic ", ""],
                      "likelyFacts": ["Looks handmade"],
                      "conflictingClues": ["Different base marks"],
                      "unknownDetails": ["maker"],
                      "possibleMatches": ["Ceramic mug with maker mark"],
                      "potentiallyValuableVariants": ["Studio pottery mark"],
                      "evidenceNeeded": ["Is there a stamp on the bottom?"],
                      "previousCorrections": ["User rejected plain mug"],
                      "confidenceState": "stillChecking"
                    }
                  }
                }
                """.utf8
            ))
        }

        let response = try await client.analyze(image: Data([1, 2, 3]))

        XCTAssertEqual(response.analysis?.itemFacts, [
            AnalyzeItemFact(label: "Material", value: "Ceramic", confidence: 1)
        ])
        XCTAssertEqual(response.analysis?.missingFacts, ["maker"])
        XCTAssertEqual(response.analysis?.photoPrompt, "Show the bottom mark.")
        XCTAssertEqual(response.analysis?.likelyMatches, [
            AnalyzeLikelyMatch(
                name: "Ceramic mug with maker mark",
                distinguishingQuestion: "Is there a stamp on the bottom?",
                confidence: 1
            )
        ])
        XCTAssertEqual(response.analysis?.referenceImages, [
            AnalyzeReferenceImage(
                title: "Similar ceramic mug",
                url: "https://example.com/mug.jpg",
                source: "Visual search"
            )
        ])
        XCTAssertEqual(response.analysis?.photoGuidance, "Show the bottom mark.")
        XCTAssertEqual(response.analysis?.detailGuidance, "Check maker if you know it.")
        XCTAssertEqual(response.analysis?.displayHint, "Show the bottom mark.")
        XCTAssertEqual(response.analysis?.identificationProfile?.confirmedFacts, ["Material: Ceramic"])
        XCTAssertEqual(response.analysis?.identificationProfile?.likelyFacts, ["Looks handmade"])
        XCTAssertEqual(response.analysis?.identificationProfile?.conflictingClues, ["Different base marks"])
        XCTAssertEqual(response.analysis?.identificationProfile?.unknownDetails, ["maker"])
        XCTAssertEqual(response.analysis?.identificationProfile?.possibleMatches, ["Ceramic mug with maker mark"])
        XCTAssertEqual(response.analysis?.identificationProfile?.potentiallyValuableVariants, ["Studio pottery mark"])
        XCTAssertEqual(response.analysis?.identificationProfile?.evidenceNeeded, ["Is there a stamp on the bottom?"])
        XCTAssertEqual(response.analysis?.identificationProfile?.previousCorrections, ["User rejected plain mug"])
        XCTAssertEqual(response.analysis?.identificationProfile?.confidenceState, .stillChecking)
        XCTAssertEqual(response.analysis?.identificationProfile?.primaryKnownSummary, "Material: Ceramic")
        XCTAssertEqual(response.analysis?.identificationProfile?.primaryUnresolvedSummary, "Conflicting clue: Different base marks")
    }

    func testAnalyzeDecodesServerControlledEarlyAccessEntitlement() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "name": "Ceramic mug",
                  "category": "Home",
                  "condition": "good",
                  "currentPrice": 9,
                  "entitlement": {
                    "state": "earlyAccess",
                    "completeFeatureAccess": true,
                    "futurePaidAccessEnabled": false,
                    "remainingAnalyses": 17,
                    "remainingAiActions": 52
                  }
                }
                """.utf8
            ))
        }

        let response = try await client.analyze(image: Data([1, 2, 3]))

        XCTAssertEqual(response.entitlement?.state, .earlyAccess)
        XCTAssertEqual(response.entitlement?.completeFeatureAccess, true)
        XCTAssertEqual(response.entitlement?.futurePaidAccessEnabled, false)
        XCTAssertEqual(response.entitlement?.remainingAnalyses, 17)
        XCTAssertEqual(response.entitlement?.remainingAiActions, 52)
        XCTAssertEqual(response.entitlement?.analyticsProperties["entitlement_state"], "earlyAccess")
    }

    func testAnalyzeUsesMissingFactGuidanceWhenNoPhotoPromptIsNeeded() async throws {
        let analysis = AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: ["serial number"],
            photoPrompt: nil
        )

        XCTAssertNil(analysis.photoGuidance)
        XCTAssertEqual(analysis.detailGuidance, "Check serial number if you know it.")
        XCTAssertEqual(analysis.displayHint, "Check serial number if you know it.")
    }

    func testAnalyzeValueQuestionsSanitizeSpecificChoices() throws {
        let analysis = AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: [],
            photoPrompt: nil,
            valueQuestions: [
                AnalyzeValueQuestion(
                    question: "Does the label say OLED or HAC-001?",
                    reason: "OLED and original models sell differently.",
                    answerField: .spec,
                    choices: ["OLED", "HAC-001", "I don't know", "OLED"],
                    unknownFollowUpQuestion: "Can you find a model number on the back?",
                    unknownFollowUpChoices: ["OLED label", "HAC-001 label", "OLED label", "   "]
                )
            ]
        )

        let sanitized = try XCTUnwrap(analysis.sanitizedForDisplay())
        let question = try XCTUnwrap(sanitized.valueQuestions.first)

        XCTAssertEqual(question.question, "Does the label say OLED or HAC-001?")
        XCTAssertEqual(question.reason, "OLED and original models sell differently.")
        XCTAssertEqual(question.answerField, .spec)
        XCTAssertEqual(question.choices, ["OLED", "HAC-001", "I don't know"])
        XCTAssertEqual(question.unknownFollowUpQuestion, "Can you find a model number on the back?")
        XCTAssertEqual(question.unknownFollowUpChoices, ["OLED label", "HAC-001 label"])
    }

    func testAnalyzeSynthesizesIdentificationProfileFromLegacyFields() throws {
        let analysis = AnalyzeIntelligence(
            itemFacts: [
                AnalyzeItemFact(label: "Brand", value: "Nintendo", confidence: 0.91),
                AnalyzeItemFact(label: "Possible color", value: "White", confidence: 0.62)
            ],
            missingFacts: ["model number"],
            photoPrompt: nil,
            likelyMatches: [
                AnalyzeLikelyMatch(
                    name: "Nintendo Switch OLED",
                    distinguishingQuestion: "Does the label say HEG-001?",
                    confidence: 0.78
                ),
                AnalyzeLikelyMatch(
                    name: "Nintendo Switch original",
                    distinguishingQuestion: "Does the label say HAC-001?",
                    confidence: 0.55
                )
            ],
            valueQuestions: [
                AnalyzeValueQuestion(
                    question: "Does it say OLED?",
                    reason: "OLED and original models sell differently.",
                    answerField: .spec,
                    choices: ["OLED", "HAC-001"]
                )
            ]
        )

        let profile = try XCTUnwrap(analysis.sanitizedForDisplay()?.identificationProfile)

        XCTAssertEqual(profile.confirmedFacts, ["Brand: Nintendo"])
        XCTAssertEqual(profile.likelyFacts, ["Possible color: White"])
        XCTAssertEqual(profile.unknownDetails, ["model number"])
        XCTAssertEqual(profile.possibleMatches, ["Nintendo Switch OLED", "Nintendo Switch original"])
        XCTAssertEqual(profile.evidenceNeeded, [
            "Does the label say HEG-001?",
            "Does the label say HAC-001?",
            "Check model number"
        ])
        XCTAssertEqual(profile.potentiallyValuableVariants, ["Does it say OLED?"])
        XCTAssertEqual(profile.confidenceState, .likely)
        XCTAssertEqual(profile.primaryKnownSummary, "Brand: Nintendo")
        XCTAssertEqual(profile.primaryUnresolvedSummary, "A few similar matches are still possible.")
    }

    func testAnalyzeBuildsTargetedScanRequestFromPhotoPrompt() {
        let labelAnalysis = AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: [],
            photoPrompt: " Show the model label. "
        )

        let labelRequest = labelAnalysis.targetedScanRequest
        XCTAssertEqual(labelRequest?.prompt, "Show the model label.")
        XCTAssertEqual(labelRequest?.role, .label)
        XCTAssertEqual(labelRequest?.benefit, "This can confirm the exact model.")
        XCTAssertEqual(labelRequest?.systemImage, "text.viewfinder")

        let barcodeAnalysis = AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: [],
            photoPrompt: "Scan the barcode for sold pricing."
        )

        let barcodeRequest = barcodeAnalysis.targetedScanRequest
        XCTAssertEqual(barcodeRequest?.role, .barcode)
        XCTAssertEqual(barcodeRequest?.benefit, "This helps us find closer sold listings.")
        XCTAssertEqual(barcodeRequest?.systemImage, "barcode.viewfinder")
    }

    func testAnalyzeDoesNotAskForTargetedScanWithoutPhotoPrompt() {
        let analysis = AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: ["serial number"],
            photoPrompt: nil
        )

        XCTAssertNil(analysis.targetedScanRequest)
    }

    func testAnalyzeGuestRequestOmitsAuthorizationHeader() async throws {
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/analyze-image")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            Self.assertDeviceIDHeader(in: request)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let imageDataURL = try XCTUnwrap(json["imageDataUrl"] as? String)
            XCTAssertTrue(imageDataURL.hasPrefix("data:image/jpeg;base64,"))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Guest mug","category":"Home","condition":"good","currentPrice":10}"#.utf8))
        }

        let response = try await client.analyze(image: Data([1, 2, 3]))

        XCTAssertEqual(response.name, "Guest mug")
        XCTAssertEqual(response.currentPrice, Decimal(10))
    }

    func testAnalyzeRejectsEmptyImageBeforeRequest() async throws {
        let client = try makeClient { _ in
            XCTFail("Empty image captures should be rejected before a network request")
            let url = try XCTUnwrap(URL(string: "https://example.supabase.co/functions/v1/analyze-image"))
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        do {
            _ = try await client.analyze(image: Data())
            XCTFail("Expected decoding error for empty image data")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testGenerateListingBuildsRequestAndReturnsValidatedTrimmedListingText() async throws {
        let item = Self.sampleItem
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/generate-listing")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["platform"] as? String, "ebay")
            let item = try XCTUnwrap(json["item"] as? [String: Any])
            XCTAssertEqual(item["name"] as? String, "Lamp")
            XCTAssertEqual(item["category"] as? String, "Home")
            XCTAssertEqual(item["condition"] as? String, "good")
            XCTAssertEqual((item["originalPrice"] as? NSNumber)?.decimalValue, Decimal(45))
            XCTAssertEqual((item["currentPrice"] as? NSNumber)?.decimalValue, Decimal(45))
            let details = try XCTUnwrap(json["details"] as? [String: Any])
            XCTAssertEqual(details["labelOrBrand"] as? String, "Stiffel")
            XCTAssertEqual(details["sizeOrModel"] as? String, "24 inches")
            XCTAssertEqual(details["flaws"] as? String, "Small scratch")
            XCTAssertEqual(details["included"] as? String, "Shade")
            XCTAssertEqual(details["extraDetails"] as? String, "Brass finish")
            let marketplaceNotes = try XCTUnwrap(details["marketplaceNotes"] as? [String: String])
            XCTAssertEqual(marketplaceNotes, ["ebay": "Prefer fixed price"])
            XCTAssertEqual(details["isLargeOrFragile"] as? Bool, true)
            let imageDataURL = try XCTUnwrap(json["imageDataUrl"] as? String)
            XCTAssertTrue(imageDataURL.hasPrefix("data:image/jpeg;base64,"))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"  \nTITLE:\nLamp\n\nDESCRIPTION:\nWorks well.\n  "}"#.utf8))
        }

        let listing = try await client.generateListing(
            item: item,
            marketplace: .ebay,
            details: ItemDetailAnswers(
                labelOrBrand: "Stiffel",
                sizeOrModel: "24 inches",
                flaws: "Small scratch",
                included: "Shade",
                extraDetails: "Brass finish",
                marketplaceNotes: [.ebay: "Prefer fixed price"],
                isLargeOrFragile: true
            ),
            imageData: ImageTools.sampleJPEG(),
            accessToken: "access-token"
        )

        XCTAssertEqual(listing, "TITLE:\nLamp\n\nDESCRIPTION:\nWorks well.")
    }

    func testGenerateListingIncludesIdentificationProfileForSpecificResearchAndListing() async throws {
        let profile = Self.sampleIdentificationProfile
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let payload = try XCTUnwrap(json["identificationProfile"] as? [String: Any])
            XCTAssertEqual(payload["confirmedFacts"] as? [String], ["Brand: Stiffel", "Material: brass"])
            XCTAssertEqual(payload["unknownDetails"] as? [String], ["Maker mark", "Height"])
            XCTAssertEqual(payload["possibleMatches"] as? [String], ["Stiffel brass table lamp", "Generic brass table lamp"])
            XCTAssertEqual(payload["potentiallyValuableVariants"] as? [String], ["Check if it has a Stiffel foil label"])
            XCTAssertEqual(payload["evidenceNeeded"] as? [String], ["Scan the maker mark"])
            XCTAssertEqual(payload["confidenceState"] as? String, "stillChecking")

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\nWorks well."}"#.utf8))
        }

        let listing = try await client.generateListing(
            item: Self.sampleItem,
            marketplace: .ebay,
            identificationProfile: profile
        )

        XCTAssertEqual(listing, "TITLE:\nLamp\n\nDESCRIPTION:\nWorks well.")
    }

    func testGenerateListingOmitsQuestionMemoryWhenNoListingDetailsWereConfirmed() async throws {
        let item = Self.sampleItem
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertNil(json["details"])

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\nWorks well."}"#.utf8))
        }

        var answers = ItemDetailAnswers()
        answers.markAnswered(.labelOrBrand)
        answers.markAnswered(.largeOrFragile)

        let listing = try await client.generateListing(
            item: item,
            marketplace: .ebay,
            details: answers,
            imageData: nil
        )

        XCTAssertEqual(listing, "TITLE:\nLamp\n\nDESCRIPTION:\nWorks well.")
    }

    func testGenerateListingIncludesSelectedMarketplaceComparisonEvidence() async throws {
        let item = Self.sampleItem
        let comparison = MarketplaceComparison(
            marketplace: .ebay,
            recommendationLabel: "Best overall",
            marketplaceFitScore: 92,
            listPrice: Decimal(45),
            likelyRangeLow: Decimal(38),
            likelyRangeHigh: Decimal(52),
            takeHomeEstimate: Decimal(39),
            compLowPrice: Decimal(30),
            compMedianPrice: Decimal(42),
            compHighPrice: Decimal(61),
            expectedSpeed: "Usually sells in a week",
            shippingExpectation: "Ship safely with padding",
            feeSummary: "Expect final value fees.",
            reason: "eBay has the best sold history for lamps.",
            evidenceSummary: "Checked close sold brass lamp comps.",
            evidenceStatus: .grounded,
            evidenceSources: [
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    title: "Sold brass lamp",
                    url: "https://example.com/sold-lamp",
                    dateChecked: "2026-07-25",
                    listingStatus: "Sold",
                    conditionAndVariant: "Good brass lamp",
                    comparability: "Close match",
                    price: Decimal(42)
                )
            ]
        )
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let payload = try XCTUnwrap(json["marketplaceComparison"] as? [String: Any])
            XCTAssertEqual(payload["marketplace"] as? String, "ebay")
            XCTAssertEqual(payload["recommendationLabel"] as? String, "Best overall")
            XCTAssertEqual(payload["marketplaceFitScore"] as? Int, 92)
            XCTAssertEqual((payload["listPrice"] as? NSNumber)?.decimalValue, Decimal(45))
            XCTAssertEqual((payload["compLowPrice"] as? NSNumber)?.decimalValue, Decimal(30))
            XCTAssertEqual((payload["compMedianPrice"] as? NSNumber)?.decimalValue, Decimal(42))
            XCTAssertEqual((payload["compHighPrice"] as? NSNumber)?.decimalValue, Decimal(61))
            XCTAssertEqual(payload["feeSummary"] as? String, "Expect final value fees.")
            XCTAssertEqual(payload["evidenceStatus"] as? String, "grounded")
            let sources = try XCTUnwrap(payload["evidenceSources"] as? [[String: Any]])
            XCTAssertEqual(sources.count, 1)
            XCTAssertEqual(sources.first?["url"] as? String, "https://example.com/sold-lamp")
            XCTAssertEqual(sources.first?["listingStatus"] as? String, "Sold")
            XCTAssertEqual((sources.first?["price"] as? NSNumber)?.decimalValue, Decimal(42))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\nWorks well."}"#.utf8))
        }

        let listing = try await client.generateListing(
            item: item,
            marketplace: .ebay,
            marketplaceComparison: comparison
        )

        XCTAssertEqual(listing, "TITLE:\nLamp\n\nDESCRIPTION:\nWorks well.")
    }

    func testGenerateListingOmitsUndecodableImageDataFromPayload() async throws {
        let item = Self.sampleItem
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertNil(json["imageDataUrl"])

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\nWorks well."}"#.utf8))
        }

        let listing = try await client.generateListing(
            item: item,
            marketplace: .ebay,
            imageData: Data([0x00, 0x01, 0x02])
        )

        XCTAssertEqual(listing, "TITLE:\nLamp\n\nDESCRIPTION:\nWorks well.")
    }

    func testGenerateListingPayloadReturnsSanitizedStructuredDraft() async throws {
        let item = Self.sampleItem
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/generate-listing")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let playbook = try XCTUnwrap(json["marketplacePlaybook"] as? [String: Any])
            let expectedPlaybook = Marketplace.ebay.listingPlaybook
            XCTAssertEqual(playbook["titleCharacterLimit"] as? Int, expectedPlaybook.titleCharacterLimit)
            XCTAssertEqual(playbook["titleFormula"] as? String, expectedPlaybook.titleFormula)
            XCTAssertEqual(playbook["descriptionGuidance"] as? String, expectedPlaybook.descriptionGuidance)
            XCTAssertEqual(playbook["requiredFields"] as? [String], expectedPlaybook.requiredFields)
            XCTAssertEqual(playbook["highImpactOptionalFields"] as? [String], expectedPlaybook.highImpactOptionalFields)
            XCTAssertEqual(playbook["recommendedPhotoSequence"] as? [String], expectedPlaybook.recommendedPhotoSequence.map(\.rawValue))
            XCTAssertEqual(playbook["pricingFormat"] as? String, expectedPlaybook.pricingFormat)
            XCTAssertEqual(playbook["shippingOrPickupGuidance"] as? String, expectedPlaybook.shippingOrPickupGuidance)
            XCTAssertEqual(playbook["officialPostURLString"] as? String, expectedPlaybook.officialPostURLString)
            XCTAssertEqual(playbook["officialHowToURLString"] as? String, expectedPlaybook.officialHowToURLString)
            XCTAssertEqual(playbook["ruleSourceURLs"] as? [String], expectedPlaybook.ruleSourceURLs)
            XCTAssertEqual(playbook["ruleSourceLastVerified"] as? String, expectedPlaybook.ruleSourceLastVerified)
            XCTAssertEqual(playbook["postingSurface"] as? String, expectedPlaybook.postingSurface.rawValue)
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (
                response,
                Data(
                    """
                    {
                      "listing": "TITLE:\\nLamp\\n\\nDESCRIPTION:\\nWorks well.\\n\\nList at: $45\\nMain photo: Show the full lamp.",
                      "draft": {
                        "title": "  Lamp  ",
                        "description": "Works well.",
                        "listPrice": 45,
                        "likelySalePrice": 40,
                        "takeHomeEstimate": 35,
                        "firstPhoto": "Show the full lamp.",
                        "missingPhotoPrompt": "Show the cord.",
                        "missingInfoWarnings": ["Confirm the brand before posting.", "Confirm the brand before posting."],
                        "fitReason": "Good broad fit.",
                        "postingNotes": ["Keep pickup details clear.", "Keep pickup details clear."],
                        "itemSpecifics": ["Brass", "Table lamp"],
                        "tags": ["lamp"],
                        "compLowPrice": 28,
                        "compMedianPrice": 42,
                        "compHighPrice": 65,
                        "feeSummary": "Craigslist has no standard listing fee for most local household goods.",
                        "pricingStrategy": "List at $45 and accept $38 or more if pickup is easy.",
                        "evidenceSummary": "Checked sold and active comparable brass lamps.",
                        "referenceImageURL": "https://example.com/lamp.jpg",
                        "publicImageQuery": "vintage brass table lamp",
                        "evidenceSources": [
                          {
                            "sourceMarketplace": "eBay",
                            "title": "Sold brass table lamp",
                            "url": "https://example.com/sold-lamp",
                            "dateChecked": "2026-07-24",
                            "listingStatus": "sold",
                            "conditionAndVariant": "Good brass lamp",
                            "comparability": "Close match",
                            "price": 42
                          },
                          {
                            "sourceMarketplace": "eBay",
                            "title": "Sold brass table lamp",
                            "url": "https://example.com/sold-lamp",
                            "dateChecked": "2026-07-24",
                            "listingStatus": "sold",
                            "conditionAndVariant": "Good brass lamp",
                            "comparability": "Close match",
                            "price": 42
                          }
                        ]
                      },
                      "entitlement": {
                        "state": "earlyAccess",
                        "completeFeatureAccess": true,
                        "futurePaidAccessEnabled": false,
                        "remainingAnalyses": 15,
                        "remainingAiActions": 41
                      }
                    }
                    """.utf8
                )
            )
        }

        let payload = try await client.generateListingPayload(item: item, marketplace: .ebay)

        XCTAssertEqual(payload.listing, "TITLE:\nLamp\n\nDESCRIPTION:\nWorks well.")
        XCTAssertFalse(payload.listing.contains("List at:"))
        XCTAssertFalse(payload.listing.contains("Main photo:"))
        XCTAssertEqual(payload.draft?.title, "Lamp")
        XCTAssertEqual(payload.draft?.listPrice, Decimal(45))
        XCTAssertEqual(payload.draft?.likelySalePrice, Decimal(40))
        XCTAssertEqual(payload.draft?.takeHomeEstimate, Decimal(35))
        XCTAssertEqual(payload.draft?.firstPhoto, "Show the full lamp.")
        XCTAssertEqual(payload.draft?.missingPhotoPrompt, "Show the cord.")
        XCTAssertEqual(payload.draft?.missingInfoWarnings, ["Confirm the brand before posting."])
        XCTAssertEqual(payload.draft?.fitReason, "Good broad fit.")
        XCTAssertEqual(payload.draft?.postingNotes, ["Keep pickup details clear."])
        XCTAssertEqual(payload.draft?.itemSpecifics, ["Brass", "Table lamp"])
        XCTAssertEqual(payload.draft?.tags, ["lamp"])
        XCTAssertEqual(payload.draft?.compLowPrice, Decimal(28))
        XCTAssertEqual(payload.draft?.compMedianPrice, Decimal(42))
        XCTAssertEqual(payload.draft?.compHighPrice, Decimal(65))
        XCTAssertEqual(payload.draft?.feeSummary, "Craigslist has no standard listing fee for most local household goods.")
        XCTAssertEqual(payload.draft?.pricingStrategy, "List at $45 and accept $38 or more if pickup is easy.")
        XCTAssertEqual(payload.draft?.evidenceSummary, "Checked sold and active comparable brass lamps.")
        XCTAssertEqual(payload.draft?.referenceImageURL, "https://example.com/lamp.jpg")
        XCTAssertEqual(payload.draft?.publicImageQuery, "vintage brass table lamp")
        XCTAssertEqual(payload.draft?.evidenceSources?.count, 1)
        let evidenceSource = try XCTUnwrap(payload.draft?.evidenceSources?.first)
        XCTAssertEqual(evidenceSource.sourceMarketplace, "eBay")
        XCTAssertEqual(evidenceSource.title, "Sold brass table lamp")
        XCTAssertEqual(evidenceSource.url, "https://example.com/sold-lamp")
        XCTAssertEqual(evidenceSource.dateChecked, "2026-07-24")
        XCTAssertEqual(evidenceSource.listingStatus, "sold")
        XCTAssertEqual(evidenceSource.conditionAndVariant, "Good brass lamp")
        XCTAssertEqual(evidenceSource.comparability, "Close match")
        XCTAssertEqual(evidenceSource.price, Decimal(42))
        XCTAssertEqual(payload.entitlement?.state, .earlyAccess)
        XCTAssertEqual(payload.entitlement?.remainingAnalyses, 15)
        XCTAssertEqual(payload.entitlement?.remainingAiActions, 41)
    }

    func testCompareMarketplacesDecodesEntitlementFromGroundedResearchResponse() async throws {
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/compare-marketplaces")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            Self.assertDeviceIDHeader(in: request)

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["candidateMarketplaces"] as? [String], ["ebay", "facebook"])

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "checkedAt": "2026-07-24T00:00:00Z",
                  "comparisons": [
                    {
                      "marketplace": "ebay",
                      "recommendationLabel": "Best overall",
                      "listPrice": 45,
                      "takeHomeEstimate": 39,
                      "reason": "Broad reach for this item.",
                      "evidenceStatus": "grounded",
                      "evidenceSources": [
                        {
                          "sourceMarketplace": "eBay",
                          "title": "Sold lamp",
                          "url": "https://example.com/sold-lamp",
                          "dateChecked": "2026-07-24",
                          "listingStatus": "sold",
                          "conditionAndVariant": "Good",
                          "comparability": "Similar",
                          "price": 42
                        }
                      ]
                    }
                  ],
                  "entitlement": {
                    "state": "earlyAccess",
                    "completeFeatureAccess": true,
                    "futurePaidAccessEnabled": false,
                    "remainingAnalyses": 14,
                    "remainingAiActions": 39
                  }
                }
                """.utf8
            ))
        }

        let response = try await client.compareMarketplaces(
            item: Self.sampleItem,
            candidateMarketplaces: [.ebay, .facebook],
            identificationProfile: Self.sampleIdentificationProfile,
            accessToken: "access-token"
        )

        XCTAssertEqual(response.entitlement?.state, .earlyAccess)
        XCTAssertEqual(response.entitlement?.remainingAnalyses, 14)
        XCTAssertEqual(response.entitlement?.remainingAiActions, 39)
        XCTAssertEqual(response.comparisons.first?.marketplace, .ebay)
        XCTAssertEqual(response.comparisons.first?.evidenceStatus, .grounded)
    }

    func testCompareMarketplacesIncludesIdentificationProfileForGroundedSearch() async throws {
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let payload = try XCTUnwrap(json["identificationProfile"] as? [String: Any])
            XCTAssertEqual(payload["confirmedFacts"] as? [String], ["Brand: Stiffel", "Material: brass"])
            XCTAssertEqual(payload["likelyFacts"] as? [String], ["Style: mid-century"])
            XCTAssertEqual(payload["unknownDetails"] as? [String], ["Maker mark", "Height"])
            XCTAssertEqual(payload["previousCorrections"] as? [String], ["User said it is not a generic lamp"])
            XCTAssertEqual(payload["confidenceState"] as? String, "stillChecking")

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "checkedAt": "2026-07-24T00:00:00Z",
                  "comparisons": [
                    {
                      "marketplace": "ebay",
                      "recommendationLabel": "Best overall",
                      "listPrice": 45,
                      "takeHomeEstimate": 39,
                      "reason": "Broad reach for this item.",
                      "evidenceStatus": "grounded",
                      "evidenceSources": [
                        {
                          "sourceMarketplace": "eBay",
                          "title": "Sold lamp",
                          "url": "https://example.com/sold-lamp",
                          "dateChecked": "2026-07-24",
                          "listingStatus": "sold",
                          "conditionAndVariant": "Good",
                          "comparability": "Similar",
                          "price": 42
                        }
                      ]
                    }
                  ]
                }
                """.utf8
            ))
        }

        let response = try await client.compareMarketplaces(
            item: Self.sampleItem,
            candidateMarketplaces: [.ebay, .facebook],
            identificationProfile: Self.sampleIdentificationProfile
        )

        XCTAssertEqual(response.comparisons.first?.marketplace, .ebay)
    }

    func testCompareMarketplacesReusesFreshGroundedEvidenceForSameItemDetailsAndCandidates() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/compare-marketplaces")

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "checkedAt": "2026-07-24T00:00:00Z",
                  "comparisons": [
                    {
                      "marketplace": "ebay",
                      "recommendationLabel": "Best overall",
                      "listPrice": 45,
                      "takeHomeEstimate": 39,
                      "reason": "Broad reach for this item.",
                      "evidenceStatus": "grounded",
                      "evidenceSources": [
                        {
                          "sourceMarketplace": "eBay",
                          "title": "Sold lamp",
                          "url": "https://example.com/sold-lamp",
                          "dateChecked": "2026-07-24",
                          "listingStatus": "sold",
                          "conditionAndVariant": "Good",
                          "comparability": "Similar",
                          "price": 42
                        }
                      ]
                    }
                  ]
                }
                """.utf8
            ))
        }

        let details = ItemDetailAnswers(labelOrBrand: "Stiffel", sizeOrModel: "24 inches")
        let firstResponse = try await client.compareMarketplaces(
            item: Self.sampleItem,
            details: details,
            candidateMarketplaces: [.ebay, .facebook]
        )
        let secondResponse = try await client.compareMarketplaces(
            item: Self.sampleItem,
            details: details,
            candidateMarketplaces: [.ebay, .facebook]
        )

        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(firstResponse, secondResponse)
        XCTAssertEqual(secondResponse.comparisons.first?.evidenceSources?.first?.title, "Sold lamp")
    }

    func testCompareMarketplacesDoesNotReuseEvidenceWhenDetailsChange() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "checkedAt": "2026-07-24T00:00:00Z",
                  "comparisons": [
                    {
                      "marketplace": "ebay",
                      "recommendationLabel": "Best overall",
                      "listPrice": 45,
                      "takeHomeEstimate": 39,
                      "reason": "Broad reach for this item.",
                      "evidenceStatus": "grounded",
                      "evidenceSources": [
                        {
                          "sourceMarketplace": "eBay",
                          "title": "Sold lamp",
                          "url": "https://example.com/sold-lamp",
                          "dateChecked": "2026-07-24",
                          "listingStatus": "sold",
                          "conditionAndVariant": "Good",
                          "comparability": "Similar",
                          "price": 42
                        }
                      ]
                    }
                  ]
                }
                """.utf8
            ))
        }

        _ = try await client.compareMarketplaces(
            item: Self.sampleItem,
            details: ItemDetailAnswers(labelOrBrand: "Stiffel"),
            candidateMarketplaces: [.ebay, .facebook]
        )
        _ = try await client.compareMarketplaces(
            item: Self.sampleItem,
            details: ItemDetailAnswers(labelOrBrand: "Stiffel", flaws: "Cracked shade"),
            candidateMarketplaces: [.ebay, .facebook]
        )

        XCTAssertEqual(attempts, 2)
    }

    func testCompareMarketplacesDoesNotReuseEvidenceWhenIdentificationProfileChanges() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "checkedAt": "2026-07-24T00:00:00Z",
                  "comparisons": [
                    {
                      "marketplace": "ebay",
                      "recommendationLabel": "Best overall",
                      "listPrice": 45,
                      "takeHomeEstimate": 39,
                      "reason": "Broad reach for this item.",
                      "evidenceStatus": "grounded",
                      "evidenceSources": [
                        {
                          "sourceMarketplace": "eBay",
                          "title": "Sold lamp",
                          "url": "https://example.com/sold-lamp",
                          "dateChecked": "2026-07-24",
                          "listingStatus": "sold",
                          "conditionAndVariant": "Good",
                          "comparability": "Similar",
                          "price": 42
                        }
                      ]
                    }
                  ]
                }
                """.utf8
            ))
        }

        _ = try await client.compareMarketplaces(
            item: Self.sampleItem,
            candidateMarketplaces: [.ebay, .facebook],
            identificationProfile: Self.sampleIdentificationProfile
        )
        _ = try await client.compareMarketplaces(
            item: Self.sampleItem,
            candidateMarketplaces: [.ebay, .facebook],
            identificationProfile: AnalyzeIdentificationProfile(
                confirmedFacts: ["Brand: Stiffel", "Material: brass", "Height: 24 inches"],
                possibleMatches: ["Stiffel brass table lamp"],
                confidenceState: .likely
            )
        )

        XCTAssertEqual(attempts, 2)
    }

    func testGenerateListingGuestRequestOmitsAuthorizationHeader() async throws {
        let item = Self.sampleItem
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/generate-listing")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            Self.assertDeviceIDHeader(in: request)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["platform"] as? String, "craigslist")
            let item = try XCTUnwrap(json["item"] as? [String: Any])
            XCTAssertEqual(item["name"] as? String, "Lamp")
            XCTAssertEqual((item["currentPrice"] as? NSNumber)?.decimalValue, Decimal(45))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nGuest Lamp\n\nDESCRIPTION:\nReady to list."}"#.utf8))
        }

        let listing = try await client.generateListing(item: item, marketplace: .craigslist)

        XCTAssertEqual(listing, "TITLE:\nGuest Lamp\n\nDESCRIPTION:\nReady to list.")
    }

    func testGenerateListingTrimsItemNameBeforeRequest() async throws {
        let item = DetectedItem(
            name: "  Lamp  ",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let item = try XCTUnwrap(json["item"] as? [String: Any])
            XCTAssertEqual(item["name"] as? String, "Lamp")

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\nReady."}"#.utf8))
        }

        let listing = try await client.generateListing(item: item, marketplace: .ebay)

        XCTAssertEqual(listing, "TITLE:\nLamp\n\nDESCRIPTION:\nReady.")
    }

    func testGenerateListingUsesStableBackendCategoryAndConditionValues() async throws {
        let item = DetectedItem(
            name: "Jacket",
            category: .clothing,
            condition: .likeNew,
            priceEstimate: Decimal(45)
        )
        let client = try makeClient { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let item = try XCTUnwrap(json["item"] as? [String: Any])
            XCTAssertEqual(item["category"] as? String, "Clothing")
            XCTAssertEqual(item["condition"] as? String, "likeNew")

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nJacket\n\nDESCRIPTION:\nClean and ready."}"#.utf8))
        }

        let listing = try await client.generateListing(item: item, marketplace: .poshmark)

        XCTAssertEqual(listing, "TITLE:\nJacket\n\nDESCRIPTION:\nClean and ready.")
    }

    func testGenerateListingRejectsInvalidItemBeforeRequest() async throws {
        let invalidItems = [
            DetectedItem(name: "  \n\t  ", category: .home, condition: .good, priceEstimate: Decimal(45)),
            DetectedItem(name: "Lamp", category: .home, condition: .good, priceEstimate: Decimal(0)),
            DetectedItem(name: "Lamp", category: .home, condition: .good, priceEstimate: Decimal(-1))
        ]

        for item in invalidItems {
            let client = try makeClient { _ in
                XCTFail("Invalid listing items should be rejected before a network request")
                let url = try XCTUnwrap(URL(string: "https://example.supabase.co/functions/v1/generate-listing"))
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil))
                return (response, Data())
            }

            do {
                _ = try await client.generateListing(item: item, marketplace: .ebay)
                XCTFail("Expected decoding error for invalid item: \(item)")
            } catch {
                XCTAssertEqual(error as? APIError, .decoding)
            }
        }
    }

    func testUITestingGenerateListingUsesSharedPolishedFixtureCopy() async throws {
        let client = APIClient(isUITesting: true)

        let listing = try await client.generateListing(item: Self.sampleItem, marketplace: .craigslist)

        XCTAssertEqual(listing, ListingFixtureText.sample(for: Self.sampleItem, marketplace: .craigslist, currencyCode: "USD"))
        XCTAssertNoThrow(try ListingTextContract.validatedGenerated(listing))
        XCTAssertFalse(listing.localizedCaseInsensitiveContains("selling a"))
        XCTAssertFalse(listing.localizedCaseInsensitiveContains("pickup or shipping depends"))
    }

    func testRateLimitMapsToFriendlyError() async {
        let client: APIClient
        do {
            client = try makeClient { request in
                let url = try XCTUnwrap(request.url)
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil))
                return (response, Data())
            }
        } catch {
            XCTFail("Could not make client: \(error)")
            return
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testMalformedAnalyzeJSONMapsToDecodingError() async throws {
        let invalidPayloads = [
            #"{"name":"Lamp","category":"Home"}"#,
            #"{"name":"  \n\t  ","category":"Home","condition":"good","currentPrice":12}"#,
            #"{"name":"Lamp","category":"Home","condition":"good","currentPrice":0}"#,
            #"{"name":"Lamp","category":"","condition":"good","currentPrice":12}"#,
            #"{"name":"Lamp","category":"Pets","condition":"good","currentPrice":12}"#,
            #"{"name":"Lamp","category":"Home","condition":"","currentPrice":12}"#,
            #"{"name":"Lamp","category":"Home","condition":"broken","currentPrice":12}"#
        ]

        for payload in invalidPayloads {
            let client = try makeClient { request in
                let url = try XCTUnwrap(request.url)
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (response, Data(payload.utf8))
            }

            do {
                _ = try await client.analyze(image: Data([1]))
                XCTFail("Expected decoding error for payload: \(payload)")
            } catch {
                XCTAssertEqual(error as? APIError, .decoding)
            }
        }
    }

    func testMalformedGenerateListingJSONMapsToDecodingError() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"title":"Lamp"}"#.utf8))
        }

        do {
            _ = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testGenerateListingAcceptsConcisePlainTitleAndDescriptionContract() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (
                response,
                Data(#"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition."}"#.utf8)
            )
        }

        let listing = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)

        XCTAssertEqual(listing, "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition.")
    }

    func testUnsafeGenerateListingResponseMapsToDecodingError() async throws {
        let invalidPayloads = [
            #"{"listing":"  \n\t  "}"#,
            #"{"listing":"Here's your listing:\nTITLE:\nLamp\n\nDESCRIPTION:\nReady."}"#,
            #"{"listing":"Here is your listing -\nTITLE:\nLamp\n\nDESCRIPTION:\nReady."}"#,
            #"{"listing":"Sure, here's your listing:\nTITLE:\nLamp\n\nDESCRIPTION:\nReady."}"#,
            #"{"listing":"Draft listing:\nTITLE:\nLamp\n\nDESCRIPTION:\nReady."}"#,
            #"{"listing":"```json\nTITLE:\nLamp\n\nDESCRIPTION:\nReady.\n```"}"#,
            #"{"listing":"TITLE:\nLamp\n\n```\n\nDESCRIPTION:\nReady."}"#,
            #"{"listing":"TITLE:\n\nDESCRIPTION:\nReady."}"#,
            #"{"listing":"TITLE:\n   \n\nDESCRIPTION:\nReady."}"#,
            #"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\n"}"#,
            #"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\n   "}"#,
            #"{"listing":"DESCRIPTION:\nReady."}"#
        ]

        for payload in invalidPayloads {
            let client = try makeClient { request in
                let url = try XCTUnwrap(request.url)
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (response, Data(payload.utf8))
            }

            do {
                _ = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)
                XCTFail("Expected decoding error for payload: \(payload)")
            } catch {
                XCTAssertEqual(error as? APIError, .decoding)
            }
        }
    }

    func testGenerateListingTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testGenerateListingOfflineMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testGenerateListingRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        do {
            _ = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testGenerateListingNonSuccessStatusMapsToServerError() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        do {
            _ = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)
            XCTFail("Expected server error")
        } catch {
            XCTAssertEqual(error as? APIError, .server(403))
        }
    }

    func testGenerateListingNetworkConnectionLostRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            if attempts == 1 {
                throw URLError(.networkConnectionLost)
            }

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nRetry Lamp\n\nDESCRIPTION:\nReady."}"#.utf8))
        }

        let listing = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(listing, "TITLE:\nRetry Lamp\n\nDESCRIPTION:\nReady.")
    }

    func testGenerateListingTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let url = try XCTUnwrap(request.url)
            if attempts == 1 {
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil))
                return (response, Data())
            }

            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nServer Retry Lamp\n\nDESCRIPTION:\nReady."}"#.utf8))
        }

        let listing = try await client.generateListing(item: Self.sampleItem, marketplace: .ebay)

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(listing, "TITLE:\nServer Retry Lamp\n\nDESCRIPTION:\nReady.")
    }

    func testTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testCannotFindHostMapsToOfflineFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.cannotFindHost)
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testNonSuccessStatusMapsToServerError() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 418, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected server error")
        } catch {
            XCTAssertEqual(error as? APIError, .server(418))
        }
    }

    func testNetworkConnectionLostRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            if attempts == 1 {
                throw URLError(.networkConnectionLost)
            }

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Book","category":"Books","condition":"good","currentPrice":8}"#.utf8))
        }

        let response = try await client.analyze(image: Data([1]))

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(response.name, "Book")
        XCTAssertEqual(response.currentPrice, Decimal(8))
    }

    func testTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let url = try XCTUnwrap(request.url)
            if attempts == 1 {
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil))
                return (response, Data())
            }

            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Chair","category":"Furniture","condition":"fair","currentPrice":25}"#.utf8))
        }

        let response = try await client.analyze(image: Data([1]))

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(response.name, "Chair")
        XCTAssertEqual(response.currentPrice, Decimal(25))
    }

    func testUserAnswersEnrichIdentificationProfileForGroundedResearch() throws {
        let profile = AnalyzeIdentificationProfile(
            confirmedFacts: ["Visible item: headphones"],
            likelyFacts: ["Color: black"],
            unknownDetails: ["Model number", "Pickup availability", "Original box"],
            possibleMatches: ["Sony WH-1000XM4", "Sony WH-1000XM5"],
            evidenceNeeded: ["Check model number", "Check pickup availability", "Check original box"],
            confidenceState: .notEnoughEvidence
        )
        let analysis = AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: ["Model number", "Pickup availability"],
            photoPrompt: nil,
            identificationProfile: profile
        )
        let answers = ItemDetailAnswers(
            labelOrBrand: "Sony",
            sizeOrModel: "WH-1000XM5",
            flaws: "Light scratches on the ear cups",
            included: "Original box and charging cable",
            marketplaceNotes: [.facebook: "Porch pickup is fine"],
            answeredFieldKeys: [.labelOrBrand, .sizeOrModel, .flaws, .included, .marketplaceNotes],
            answeredMarketplaces: [.facebook]
        )
        let item = DetectedItem(
            name: "Wireless headphones",
            category: .electronics,
            condition: .good,
            priceEstimate: Decimal(180)
        )

        let enriched = try XCTUnwrap(
            AnalyzeIntelligence.enriching(
                analysis,
                with: answers,
                item: item,
                marketplace: .facebook
            )
        )
        let enrichedProfile = try XCTUnwrap(enriched.identificationProfile)

        XCTAssertTrue(enrichedProfile.confirmedFacts.contains("Seller confirmed brand or mark: Sony"))
        XCTAssertTrue(enrichedProfile.confirmedFacts.contains("Seller confirmed model or size: WH-1000XM5"))
        XCTAssertTrue(enrichedProfile.confirmedFacts.contains("Seller confirmed condition: Light scratches on the ear cups"))
        XCTAssertTrue(enrichedProfile.confirmedFacts.contains("Seller confirmed included items: Original box and charging cable"))
        XCTAssertTrue(enrichedProfile.confirmedFacts.contains("Facebook detail: Porch pickup is fine"))
        XCTAssertFalse(enrichedProfile.unknownDetails.contains("Model number"))
        XCTAssertFalse(enrichedProfile.unknownDetails.contains("Pickup availability"))
        XCTAssertFalse(enrichedProfile.evidenceNeeded.contains("Check model number"))
        XCTAssertFalse(enrichedProfile.evidenceNeeded.contains("Check pickup availability"))
        XCTAssertNotEqual(enrichedProfile.confidenceState, .notEnoughEvidence)
    }

    private static var sampleItem: DetectedItem {
        DetectedItem(name: "Lamp", category: .home, condition: .good, priceEstimate: Decimal(45))
    }

    private static var sampleIdentificationProfile: AnalyzeIdentificationProfile {
        AnalyzeIdentificationProfile(
            confirmedFacts: ["Brand: Stiffel", "Material: brass"],
            likelyFacts: ["Style: mid-century"],
            unknownDetails: ["Maker mark", "Height"],
            possibleMatches: ["Stiffel brass table lamp", "Generic brass table lamp"],
            potentiallyValuableVariants: ["Check if it has a Stiffel foil label"],
            evidenceNeeded: ["Scan the maker mark"],
            previousCorrections: ["User said it is not a generic lamp"],
            confidenceState: .stillChecking
        )
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) throws -> APIClient {
        MockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        return APIClient(session: session, config: config, isUITesting: false)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 {
                return nil
            }
            if count == 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }

    private static func assertDeviceIDHeader(
        in request: URLRequest,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let value = request.value(forHTTPHeaderField: "X-BuySell-Device-ID")
        XCTAssertNotNil(value.flatMap(UUID.init(uuidString:)), file: file, line: line)
    }

    private static func makeJPEG(width: CGFloat, height: CGFloat) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.white.setFill()
            context.fill(CGRect(x: width * 0.2, y: height * 0.2, width: width * 0.6, height: height * 0.6))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.92))
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
