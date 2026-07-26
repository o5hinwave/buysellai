import Foundation
import XCTest
@testable import BuySellAI

final class RemoteHistoryClientTests: XCTestCase {
    override func tearDown() {
        RemoteHistoryMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchHistoryBuildsPostgRESTRequestAndMapsRows() async throws {
        let entryID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let client = try makeClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.scheme, "https")
            XCTAssertEqual(components.host, "example.supabase.co")
            XCTAssertEqual(components.path, "/rest/v1/history")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "order" })?.value, "created_at.desc")
            let select = try XCTUnwrap(components.queryItems?.first(where: { $0.name == "select" })?.value)
            XCTAssertTrue(select.contains("identification_profile"))
            XCTAssertTrue(select.contains("marketplace_comparison"))
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = Data("""
            [{
              "id": "\(entryID.uuidString)",
              "created_at": "2026-07-14T19:00:00Z",
              "item_name": "Lamp",
              "category": "home",
              "condition": "good",
              "suggested_price": 45,
              "image_thumbnail_base64": "AQID",
              "marketplace": "ebay",
              "listing_text": "TITLE:\\nLamp\\n\\nDESCRIPTION:\\nLamp in good condition."
            }]
            """.utf8)
            return (response, data)
        }

        let entries = try await client.fetchHistory(accessToken: "access-token")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, entryID)
        XCTAssertEqual(entries[0].itemName, "Lamp")
        XCTAssertEqual(entries[0].category, .home)
        XCTAssertEqual(entries[0].condition, .good)
        XCTAssertEqual(entries[0].suggestedPrice, Decimal(45))
        XCTAssertEqual(entries[0].imageThumbnail, Data([1, 2, 3]))
        XCTAssertEqual(entries[0].marketplace, .ebay)
        XCTAssertEqual(entries[0].listingText, "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition.")
    }

    func testFetchHistoryDeduplicatesRowsByIDKeepingNewestServerOrder() async throws {
        let duplicateID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let blankListingID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let uniqueID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let blankNameID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = Data("""
            [
              {
                "id": "\(duplicateID.uuidString)",
                "created_at": "2026-07-14T21:00:00Z",
                "item_name": "Newest lamp",
                "category": "home",
                "condition": "good",
                "suggested_price": 45,
                "image_thumbnail_base64": null,
                "marketplace": "ebay",
                "listing_text": "TITLE:\\nNewest lamp\\n\\nDESCRIPTION:\\nNewest lamp in good condition."
              },
              {
                "id": "\(duplicateID.uuidString)",
                "created_at": "2026-07-14T20:00:00Z",
                "item_name": "Older duplicate lamp",
                "category": "home",
                "condition": "fair",
                "suggested_price": 25,
                "image_thumbnail_base64": null,
                "marketplace": "craigslist",
                "listing_text": "TITLE:\\nOlder lamp\\n\\nDESCRIPTION:\\nOlder lamp in fair condition."
              },
              {
                "id": "\(blankListingID.uuidString)",
                "created_at": "2026-07-14T19:30:00Z",
                "item_name": "Blank listing",
                "category": "home",
                "condition": "good",
                "suggested_price": 20,
                "image_thumbnail_base64": null,
                "marketplace": "ebay",
                "listing_text": "  \\n\\t  "
              },
              {
                "id": "\(uniqueID.uuidString)",
                "created_at": "2026-07-14T19:00:00Z",
                "item_name": "Chair",
                "category": "furniture",
                "condition": "fair",
                "suggested_price": 30,
                "image_thumbnail_base64": null,
                "marketplace": "craigslist",
                "listing_text": "TITLE:\\nChair\\n\\nDESCRIPTION:\\nChair in fair condition."
              },
              {
                "id": "\(blankNameID.uuidString)",
                "created_at": "2026-07-14T18:30:00Z",
                "item_name": "  \\n\\t  ",
                "category": "home",
                "condition": "good",
                "suggested_price": 20,
                "image_thumbnail_base64": null,
                "marketplace": "ebay",
                "listing_text": "TITLE:\\nBlank name\\n\\nDESCRIPTION:\\nBlank name in good condition."
              }
            ]
            """.utf8)
            return (response, data)
        }

        let entries = try await client.fetchHistory(accessToken: "access-token")

        XCTAssertEqual(entries.map(\.id), [duplicateID, uniqueID])
        XCTAssertEqual(entries.map(\.itemName), ["Newest lamp", "Chair"])
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
    }

    func testFetchHistoryAcceptsDisplayFormattedCategoryConditionAndMarketplace() async throws {
        let entryID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = Data("""
            [{
              "id": "\(entryID.uuidString)",
              "created_at": "2026-07-14T19:00:00Z",
              "item_name": "Coat",
              "category": "Clothing",
              "condition": "Like New",
              "suggested_price": 55,
              "image_thumbnail_base64": null,
              "marketplace": "Facebook Marketplace",
              "listing_text": "TITLE:\\nCoat\\n\\nDESCRIPTION:\\nCoat in like new condition.",
              "item_details": { "labelOrBrand": "Wool", "flaws": "", "sizeOrModel": "M" },
              "marketplace_comparison": {
                "marketplace": "facebook",
                "recommendationLabel": "Fastest sale",
                "listPrice": 60,
                "takeHomeEstimate": 60,
                "compLowPrice": 45,
                "compMedianPrice": 55,
                "compHighPrice": 70,
                "feeSummary": "Local sale with no platform selling fee.",
                "evidenceSummary": "Checked recent local coat comps.",
                "evidenceStatus": "grounded",
                "evidenceSources": [{
                  "sourceMarketplace": "Facebook Marketplace",
                  "title": "Sold wool coat",
                  "dateChecked": "2026-07-24",
                  "listingStatus": "sold",
                  "price": 55
                }]
              },
              "listing_draft": {
                "title": "Wool Coat",
                "description": "Wool coat in like new condition.",
                "evidenceSummary": "Checked recent comparable coats.",
                "evidenceSources": [{
                  "sourceMarketplace": "eBay",
                  "title": "Sold wool coat",
                  "dateChecked": "2026-07-24",
                  "listingStatus": "sold",
                  "price": 58
                }]
              },
              "identification_profile": {
                "confirmedFacts": ["Brand: Wool"],
                "likelyFacts": ["Looks like a winter coat"],
                "conflictingClues": [],
                "unknownDetails": ["material blend"],
                "possibleMatches": ["Wool blend overcoat"],
                "potentiallyValuableVariants": ["Cashmere blend"],
                "evidenceNeeded": ["Photo of fabric tag"],
                "previousCorrections": ["User rejected trench coat"],
                "confidenceState": "stillChecking"
              }
            }]
            """.utf8)
            return (response, data)
        }

        let entries = try await client.fetchHistory(accessToken: "access-token")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, entryID)
        XCTAssertEqual(entries[0].category, .clothing)
        XCTAssertEqual(entries[0].condition, .likeNew)
        XCTAssertEqual(entries[0].marketplace, .facebook)
        XCTAssertEqual(entries[0].itemDetails?.labelOrBrand, "Wool")
        XCTAssertEqual(entries[0].itemDetails?.sizeOrModel, "M")
        XCTAssertEqual(entries[0].marketplaceComparison?.recommendationLabel, "Fastest sale")
        XCTAssertEqual(entries[0].marketplaceComparison?.compMedianPrice, Decimal(55))
        XCTAssertEqual(entries[0].marketplaceComparison?.evidenceSources?.first?.listingStatus, "sold")
        XCTAssertEqual(entries[0].listingDraft?.evidenceSummary, "Checked recent comparable coats.")
        XCTAssertEqual(entries[0].listingDraft?.evidenceSources?.first?.listingStatus, "sold")
        XCTAssertEqual(entries[0].identificationProfile?.confirmedFacts, ["Brand: Wool"])
        XCTAssertEqual(entries[0].identificationProfile?.unknownDetails, ["material blend"])
        XCTAssertEqual(entries[0].identificationProfile?.confidenceState, .stillChecking)
    }

    func testUpsertHistoryBuildsBatchPostgRESTRequest() async throws {
        let entryID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T19:30:00Z"))
        let entry = HistoryEntry(
            id: entryID,
            createdAt: createdAt,
            itemName: "Chair",
            category: .furniture,
            condition: .fair,
            suggestedPrice: Decimal(30),
            imageThumbnail: Data([4, 5, 6]),
            marketplace: .craigslist,
            listingText: "TITLE:\nChair\n\nDESCRIPTION:\nChair in fair condition.",
            itemDetails: ItemDetailAnswers(labelOrBrand: "Oak", isLargeOrFragile: true),
            marketplaceComparison: MarketplaceComparison(
                marketplace: .craigslist,
                recommendationLabel: "Easiest option",
                listPrice: Decimal(32),
                takeHomeEstimate: Decimal(32),
                compLowPrice: Decimal(25),
                compMedianPrice: Decimal(28),
                compHighPrice: Decimal(40),
                expectedSpeed: "Likely local interest within a week.",
                feeSummary: "Local pickup avoids shipping.",
                evidenceSummary: "Checked recent local chair sales.",
                evidenceStatus: .grounded,
                evidenceSources: [
                    ListingEvidenceSource(
                        sourceMarketplace: "Craigslist",
                        title: "Sold oak chair",
                        dateChecked: "2026-07-24",
                        listingStatus: "sold",
                        price: Decimal(28)
                    )
                ]
            ),
            listingDraft: GeneratedListingDraft(
                title: "Oak Chair",
                description: "Oak chair in fair condition.",
                evidenceSummary: "Checked recent local chair listings.",
                evidenceSources: [
                    ListingEvidenceSource(
                        sourceMarketplace: "Craigslist",
                        title: "Sold oak chair",
                        dateChecked: "2026-07-24",
                        listingStatus: "sold",
                        price: Decimal(28)
                    )
                ]
            ),
            identificationProfile: AnalyzeIdentificationProfile(
                confirmedFacts: ["Material: oak"],
                likelyFacts: ["Dining chair"],
                unknownDetails: ["maker stamp"],
                possibleMatches: ["Oak dining chair"],
                potentiallyValuableVariants: ["Mid-century maker"],
                evidenceNeeded: ["Photo of underside mark"],
                confidenceState: .likely
            )
        )
        let client = try makeClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.path, "/rest/v1/history")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "on_conflict" })?.value, "id")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=minimal")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
            XCTAssertEqual(rows.count, 1)
            let row = try XCTUnwrap(rows.first)
            XCTAssertEqual(row["id"] as? String, entryID.uuidString)
            XCTAssertEqual(row["item_name"] as? String, "Chair")
            XCTAssertEqual(row["category"] as? String, "furniture")
            XCTAssertEqual(row["condition"] as? String, "fair")
            XCTAssertEqual(row["suggested_price"] as? Int, 30)
            XCTAssertEqual(row["image_thumbnail_base64"] as? String, "BAUG")
            XCTAssertEqual(row["marketplace"] as? String, "craigslist")
            XCTAssertEqual(row["listing_text"] as? String, "TITLE:\nChair\n\nDESCRIPTION:\nChair in fair condition.")
            let itemDetails = try XCTUnwrap(row["item_details"] as? [String: Any])
            XCTAssertEqual(itemDetails["labelOrBrand"] as? String, "Oak")
            XCTAssertEqual(itemDetails["isLargeOrFragile"] as? Bool, true)
            let marketplaceComparison = try XCTUnwrap(row["marketplace_comparison"] as? [String: Any])
            XCTAssertEqual(marketplaceComparison["recommendationLabel"] as? String, "Easiest option")
            XCTAssertEqual(marketplaceComparison["evidenceSummary"] as? String, "Checked recent local chair sales.")
            let comparisonSources = try XCTUnwrap(marketplaceComparison["evidenceSources"] as? [[String: Any]])
            XCTAssertEqual(comparisonSources.first?["listingStatus"] as? String, "sold")
            let listingDraft = try XCTUnwrap(row["listing_draft"] as? [String: Any])
            XCTAssertEqual(listingDraft["evidenceSummary"] as? String, "Checked recent local chair listings.")
            let sources = try XCTUnwrap(listingDraft["evidenceSources"] as? [[String: Any]])
            XCTAssertEqual(sources.first?["listingStatus"] as? String, "sold")
            let identificationProfile = try XCTUnwrap(row["identification_profile"] as? [String: Any])
            XCTAssertEqual(identificationProfile["confirmedFacts"] as? [String], ["Material: oak"])
            XCTAssertEqual(identificationProfile["unknownDetails"] as? [String], ["maker stamp"])
            XCTAssertEqual(identificationProfile["confidenceState"] as? String, "likely")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.upsertHistory([
            Self.sampleEntry(itemName: "  \n\t  ", listingText: "TITLE:\nBlank name\n\nDESCRIPTION:\nBlank name in good condition."),
            entry,
            Self.sampleEntry(itemName: "Blank listing", listingText: "  \n\t  ")
        ], accessToken: "access-token")
    }

    func testFetchHistoryMalformedJSONMapsToDecodingError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"id":"not an array"}"#.utf8))
        }

        do {
            _ = try await client.fetchHistory(accessToken: "access-token")
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testFetchHistoryTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.fetchHistory(accessToken: "access-token")
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testFetchHistoryOfflineMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await client.fetchHistory(accessToken: "access-token")
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testFetchHistoryRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            _ = try await client.fetchHistory(accessToken: "access-token")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testFetchHistoryUnauthorizedStatusMapsToSessionExpiredError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            _ = try await client.fetchHistory(accessToken: "access-token")
            XCTFail("Expected session expired error")
        } catch {
            XCTAssertEqual(error as? APIError, .sessionExpired)
        }
    }

    func testFetchHistoryNetworkConnectionLostRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            if attempts == 1 {
                throw URLError(.networkConnectionLost)
            }

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data("[]".utf8))
        }

        let entries = try await client.fetchHistory(accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
        XCTAssertTrue(entries.isEmpty)
    }

    func testFetchHistoryTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: attempts == 1 ? 503 : 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, attempts == 1 ? Data() : Data("[]".utf8))
        }

        let entries = try await client.fetchHistory(accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
        XCTAssertTrue(entries.isEmpty)
    }

    func testUpsertHistoryEmptyBatchSkipsNetworkRequest() async throws {
        let client = try makeClient { _ in
            XCTFail("Empty upsert should not make a network request.")
            throw URLError(.badURL)
        }

        try await client.upsertHistory([], accessToken: "access-token")
        try await client.upsertHistory([
            Self.sampleEntry(itemName: "  \n\t  ", listingText: "TITLE:\nBlank name\n\nDESCRIPTION:\nBlank name in good condition."),
            Self.sampleEntry(itemName: "Blank listing", listingText: "  \n\t  ")
        ], accessToken: "access-token")
    }

    func testUpsertHistoryTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            try await client.upsertHistory([Self.sampleEntry()], accessToken: "access-token")
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testUpsertHistoryOfflineMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await client.upsertHistory([Self.sampleEntry()], accessToken: "access-token")
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testUpsertHistoryUnauthorizedStatusMapsToSessionExpiredError() async throws {
        let entry = Self.sampleEntry()
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            try await client.upsertHistory([entry], accessToken: "access-token")
            XCTFail("Expected session expired error")
        } catch {
            XCTAssertEqual(error as? APIError, .sessionExpired)
        }
    }

    func testUpsertHistoryRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            try await client.upsertHistory([Self.sampleEntry()], accessToken: "access-token")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testUpsertHistoryNetworkConnectionLostRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            if attempts == 1 {
                throw URLError(.networkConnectionLost)
            }

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.upsertHistory([Self.sampleEntry()], accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    func testUpsertHistoryTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: attempts == 1 ? 503 : 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.upsertHistory([Self.sampleEntry()], accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    func testDeleteHistoryRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            try await client.deleteHistory(id: UUID(), accessToken: "access-token")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testDeleteHistoryTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            try await client.deleteHistory(id: UUID(), accessToken: "access-token")
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testDeleteHistoryOfflineMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await client.deleteHistory(id: UUID(), accessToken: "access-token")
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testDeleteHistoryUnauthorizedStatusMapsToSessionExpiredError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            try await client.deleteHistory(id: UUID(), accessToken: "access-token")
            XCTFail("Expected session expired error")
        } catch {
            XCTAssertEqual(error as? APIError, .sessionExpired)
        }
    }

    func testDeleteHistoryNetworkConnectionLostRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            if attempts == 1 {
                throw URLError(.networkConnectionLost)
            }

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.deleteHistory(id: UUID(), accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    func testDeleteHistoryTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: attempts == 1 ? 503 : 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.deleteHistory(id: UUID(), accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    func testClearHistoryTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            try await client.clearHistory(accessToken: "access-token")
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testClearHistoryOfflineMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await client.clearHistory(accessToken: "access-token")
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testClearHistoryRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            try await client.clearHistory(accessToken: "access-token")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testClearHistoryUnauthorizedStatusMapsToSessionExpiredError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            try await client.clearHistory(accessToken: "access-token")
            XCTFail("Expected session expired error")
        } catch {
            XCTAssertEqual(error as? APIError, .sessionExpired)
        }
    }

    func testClearHistoryNetworkConnectionLostRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            if attempts == 1 {
                throw URLError(.networkConnectionLost)
            }

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.clearHistory(accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    func testClearHistoryTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: attempts == 1 ? 503 : 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.clearHistory(accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    private static func sampleEntry(
        itemName: String = "Lamp",
        listingText: String = "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition."
    ) -> HistoryEntry {
        HistoryEntry(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_784_679_600),
            itemName: itemName,
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(20),
            imageThumbnail: nil,
            marketplace: .ebay,
            listingText: listingText
        )
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) throws -> RemoteHistoryClient {
        RemoteHistoryMockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteHistoryMockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        return RemoteHistoryClient(session: session, config: config)
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

private final class RemoteHistoryMockURLProtocol: URLProtocol {
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
