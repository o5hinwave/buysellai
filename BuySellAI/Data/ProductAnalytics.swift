import Foundation
import os

enum ProductAnalyticsEvent: String, CaseIterable, Sendable {
    case appOpened = "app_opened"
    case photoCaptured = "photo_captured"
    case identificationCompleted = "identification_completed"
    case identificationCorrected = "identification_corrected"
    case followUpQuestionAnswered = "follow_up_question_answered"
    case followUpQuestionsCompleted = "follow_up_questions_completed"
    case groundedResearchStarted = "grounded_research_started"
    case groundedResearchCompleted = "grounded_research_completed"
    case groundedResearchFailed = "grounded_research_failed"
    case marketplaceSelected = "marketplace_selected"
    case listingGenerated = "listing_generated"
    case listingGenerationFailed = "listing_generation_failed"
    case listingCopiedOrExported = "listing_copied_or_exported"
    case itemSaved = "item_saved"
    case userCreatedSecondListing = "user_created_second_listing"
    case userReturnedAfter1Day = "user_returned_after_1_day"
    case userReturnedAfter7Days = "user_returned_after_7_days"
    case userReturnedAfter30Days = "user_returned_after_30_days"
    case rateLimitReached = "rate_limit_reached"
    case identificationFailed = "identification_failed"
}

enum ProductAnalytics {
    private static let logger = Logger(subsystem: "BuySellAI", category: "ProductAnalytics")
    private static let lastOpenKey = "BuySell.analytics.lastOpenDate"
    private static let firstOpenKey = "BuySell.analytics.firstOpenDate"
    private static let returnedAfter1DayKey = "BuySell.analytics.returnedAfter1Day"
    private static let returnedAfter7DaysKey = "BuySell.analytics.returnedAfter7Days"
    private static let returnedAfter30DaysKey = "BuySell.analytics.returnedAfter30Days"

    static func record(_ event: ProductAnalyticsEvent, properties: [String: String] = [:]) {
        let payload = sanitizedPayload(properties)
        if payload.isEmpty {
            logger.info("event=\(event.rawValue, privacy: .public)")
        } else {
            logger.info("event=\(event.rawValue, privacy: .public) \(payload, privacy: .public)")
        }
    }

    static func recordAppOpened(defaults: UserDefaults = .standard, now: Date = Date()) {
        record(.appOpened)

        let firstOpenDate = (defaults.object(forKey: firstOpenKey) as? Date) ?? now
        if defaults.object(forKey: firstOpenKey) == nil {
            defaults.set(firstOpenDate, forKey: firstOpenKey)
        }

        recordReturnMilestones(defaults: defaults, firstOpenDate: firstOpenDate, now: now)
        defaults.set(now, forKey: lastOpenKey)
    }

    private static func recordReturnMilestones(defaults: UserDefaults, firstOpenDate: Date, now: Date) {
        let elapsedDays = max(Calendar.current.dateComponents([.day], from: firstOpenDate, to: now).day ?? 0, 0)
        recordReturnMilestone(
            event: .userReturnedAfter1Day,
            key: returnedAfter1DayKey,
            minimumElapsedDays: 1,
            elapsedDays: elapsedDays,
            defaults: defaults
        )
        recordReturnMilestone(
            event: .userReturnedAfter7Days,
            key: returnedAfter7DaysKey,
            minimumElapsedDays: 7,
            elapsedDays: elapsedDays,
            defaults: defaults
        )
        recordReturnMilestone(
            event: .userReturnedAfter30Days,
            key: returnedAfter30DaysKey,
            minimumElapsedDays: 30,
            elapsedDays: elapsedDays,
            defaults: defaults
        )
    }

    private static func recordReturnMilestone(
        event: ProductAnalyticsEvent,
        key: String,
        minimumElapsedDays: Int,
        elapsedDays: Int,
        defaults: UserDefaults
    ) {
        guard elapsedDays >= minimumElapsedDays,
              defaults.bool(forKey: key) == false
        else { return }
        record(event, properties: ["days_since_first_open": "\(elapsedDays)"])
        defaults.set(true, forKey: key)
    }

    static func recordRateLimit(endpoint: String) {
        record(.rateLimitReached, properties: ["endpoint": safeEndpoint(endpoint)])
    }

    static func recordFailure(
        _ event: ProductAnalyticsEvent,
        endpoint: String,
        error: Error,
        extra: [String: String] = [:]
    ) {
        var properties = extra
        properties["endpoint"] = safeEndpoint(endpoint)
        properties["error_kind"] = errorKind(error)
        record(event, properties: properties)
    }

    static func recordEstimatedCost(
        event: ProductAnalyticsEvent,
        endpoint: String,
        estimatedAICostCents: Decimal,
        groundedSearchCount: Int,
        extra: [String: String] = [:]
    ) {
        var properties = extra
        properties["endpoint"] = safeEndpoint(endpoint)
        properties["estimated_ai_cost_cents"] = decimalString(estimatedAICostCents)
        properties["grounded_search_count"] = "\(max(groundedSearchCount, 0))"
        record(event, properties: properties)
    }

    static func sanitizedPayload(_ properties: [String: String]) -> String {
        properties
            .map { key, value in (sanitizeKey(key), sanitizeValue(value)) }
            .filter { key, value in
                key.isEmpty == false &&
                    value.isEmpty == false &&
                    isSensitiveKey(key) == false
            }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: " ")
    }

    private static let safeCoarseKeys: Set<String> = [
        "image_bytes_bucket",
        "photo_scope"
    ]

    private static let sensitiveKeys: Set<String> = [
        "email",
        "item_name",
        "listing_title",
        "listing_description",
        "listing_text",
        "description",
        "error_message",
        "image",
        "image_data",
        "image_url",
        "localized_error",
        "message",
        "photo_url",
        "raw_error",
        "url",
        "source_url",
        "serial",
        "serial_number",
        "phone",
        "address",
        "pickup_address",
        "street_address"
    ]

    private static let sensitiveKeyFragments: Set<String> = [
        "email",
        "itemname",
        "listingtitle",
        "listingdescription",
        "listingtext",
        "description",
        "errormessage",
        "imagedata",
        "imageurl",
        "localizederror",
        "photourl",
        "rawerror",
        "sourceurl",
        "serialnumber",
        "pickupaddress",
        "streetaddress"
    ]

    private static func isSensitiveKey(_ key: String) -> Bool {
        guard safeCoarseKeys.contains(key) == false else { return false }
        if sensitiveKeys.contains(key) { return true }
        let normalizedKey = key.filter { $0.isLetter || $0.isNumber }
        if normalizedKey == "url" || normalizedKey == "image" {
            return true
        }
        return sensitiveKeyFragments.contains { normalizedKey.contains($0) }
    }

    private static func sanitizeKey(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            .prefixString(40)
    }

    private static func sanitizeValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
            .filter { $0.isLetter || $0.isNumber || "_-.:".contains($0) }
            .prefixString(80)
    }

    private static func safeEndpoint(_ value: String) -> String {
        value
            .split(separator: "?")
            .first
            .map(String.init) ?? "unknown"
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: max(value, Decimal(0))).stringValue
    }

    private static func errorKind(_ error: Error) -> String {
        switch APIError.mapTransport(error) {
        case .offline:
            "offline"
        case .timeout:
            "timeout"
        case .rateLimited:
            "rate_limited"
        case .server(let code):
            "server_\(code)"
        case .decoding:
            "decoding"
        case .notConfigured:
            "not_configured"
        case .sessionExpired:
            "session_expired"
        case .accountAlreadyLinked:
            "account_already_linked"
        case .unknown:
            "unknown"
        }
    }
}

private extension StringProtocol {
    func prefixString(_ maxLength: Int) -> String {
        String(prefix(maxLength))
    }
}
