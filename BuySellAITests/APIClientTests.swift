import Foundation
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
                    ]
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

    func testAnalyzeGuestRequestOmitsAuthorizationHeader() async throws {
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/analyze-image")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
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
    }

    func testGenerateListingGuestRequestOmitsAuthorizationHeader() async throws {
        let item = Self.sampleItem
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/generate-listing")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
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

    private static var sampleItem: DetectedItem {
        DetectedItem(name: "Lamp", category: .home, condition: .good, priceEstimate: Decimal(45))
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
