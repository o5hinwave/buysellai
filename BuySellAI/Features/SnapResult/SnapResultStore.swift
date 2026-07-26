import Observation
import Foundation

@MainActor
@Observable
final class SnapResultStore {
    typealias AnalyzeHandler = (Data, String?) async throws -> AnalyzeResponse
    typealias AnalyzeWithEvidenceHandler = (Data, NativeScanEvidence?, String?) async throws -> AnalyzeResponse
    typealias ScanEvidenceHandler = (Data) async -> NativeScanEvidence?

    enum Phase: Equatable {
        case idle
        case loading
        case success
        case failed(String)
    }

    let imageData: Data
    var phase: Phase = .idle
    var item: DetectedItem?
    var nameText = ""
    var priceText = ""
    var analysisDetails: AnalyzeIntelligence?
    var analysisGuidance: String?
    var nativeScanEvidence: NativeScanEvidence?
    var photoQualityPrompt: String?
    var confirmedLikelyMatchName: String?
    var entitlementSnapshot: EntitlementSnapshot?
    var showStillWorking = false

    private let analyzeHandler: AnalyzeWithEvidenceHandler
    private let scanEvidenceHandler: ScanEvidenceHandler
    private let stillWorkingDelayNanoseconds: UInt64
    private var analysisGeneration = 0
    private var stillWorkingTask: Task<Void, Never>?

    init(
        imageData: Data,
        stillWorkingDelayNanoseconds: UInt64 = 16_000_000_000,
        scanEvidenceHandler: @escaping ScanEvidenceHandler = { imageData in
            await NativeScanAnalyzer.evidence(from: imageData)
        },
        analyzeHandler: @escaping AnalyzeWithEvidenceHandler = { imageData, nativeScanEvidence, accessToken in
            try await APIClient.shared.analyze(
                image: imageData,
                nativeScanEvidence: nativeScanEvidence,
                accessToken: accessToken
            )
        }
    ) {
        self.imageData = imageData
        self.stillWorkingDelayNanoseconds = stillWorkingDelayNanoseconds
        self.scanEvidenceHandler = scanEvidenceHandler
        self.analyzeHandler = analyzeHandler
    }

    init(
        imageData: Data,
        stillWorkingDelayNanoseconds: UInt64 = 16_000_000_000,
        analyzeHandler: @escaping AnalyzeHandler
    ) {
        self.imageData = imageData
        self.stillWorkingDelayNanoseconds = stillWorkingDelayNanoseconds
        self.scanEvidenceHandler = { _ in nil }
        self.analyzeHandler = { imageData, _, accessToken in
            try await analyzeHandler(imageData, accessToken)
        }
    }

    func analyzeIfNeeded(accessToken: String?) async {
        guard phase == .idle else { return }
        await analyze(accessToken: accessToken)
    }

    func analyze(accessToken: String?) async {
        analysisGeneration += 1
        let generation = analysisGeneration
        cancelStillWorkingTask()
        phase = .loading
        showStillWorking = false
        item = nil
        analysisDetails = nil
        analysisGuidance = nil
        nativeScanEvidence = nil
        photoQualityPrompt = nil
        confirmedLikelyMatchName = nil
        entitlementSnapshot = nil

        stillWorkingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: stillWorkingDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            if phase == .loading, generation == analysisGeneration {
                showStillWorking = true
            }
        }

        do {
            let evidence = await scanEvidenceHandler(imageData)
            guard generation == analysisGeneration else { return }
            nativeScanEvidence = evidence
            photoQualityPrompt = evidence?.photoQuality?.fixPrompt
            let response = try await analyzeHandler(imageData, evidence, accessToken).validatedForDisplay()
            guard generation == analysisGeneration else { return }
            cancelStillWorkingTask()
            guard let priceEstimate = Self.listingPriceEstimate(from: response.currentPrice) else {
                throw APIError.decoding
            }
            let detected = DetectedItem(
                name: response.name,
                category: Category(apiValue: response.category),
                condition: Condition(apiValue: response.condition),
                priceEstimate: priceEstimate
            )
            item = detected
            nameText = detected.name
            priceText = NSDecimalNumber(decimal: detected.priceEstimate).stringValue
            analysisDetails = response.analysis
            analysisGuidance = photoQualityPrompt ?? response.analysis?.displayHint
            entitlementSnapshot = response.entitlement
            phase = .success
            ProductAnalytics.record(
                .identificationCompleted,
                properties: [
                    "category": detected.category.rawValue,
                    "condition": detected.condition.rawValue,
                    "likely_match_count": "\(response.analysis?.likelyMatches.count ?? 0)",
                    "missing_fact_count": "\(response.analysis?.missingFacts.count ?? 0)",
                    "price_bucket": Self.priceBucket(for: detected.priceEstimate)
                ]
            )
            AnalysisFeedback.performSuccess()
        } catch let error where APIError.isCancellation(error) {
            guard generation == analysisGeneration else { return }
            cancelStillWorkingTask()
            phase = .idle
            showStillWorking = false
        } catch {
            guard generation == analysisGeneration else { return }
            cancelStillWorkingTask()
            ProductAnalytics.recordFailure(
                .identificationFailed,
                endpoint: "analyze-image",
                error: error,
                extra: [
                    "image_bytes_bucket": Self.imageSizeBucket(for: imageData.count),
                    "native_scan_evidence": nativeScanEvidence == nil ? "false" : "true"
                ]
            )
            phase = .failed(APIError.userMessage(for: error))
            analysisDetails = nil
            analysisGuidance = nil
            AnalysisFeedback.performFailure()
        }
    }

    func cycleCategory() {
        commitEdits()
        guard var edited = item else { return }
        edited.category = edited.category.next()
        item = edited
        recordIdentificationCorrection(field: "category", item: edited)
    }

    func cycleCondition() {
        commitEdits()
        guard var edited = item else { return }
        edited.condition = edited.condition.next()
        item = edited
        recordIdentificationCorrection(field: "condition", item: edited)
    }

    func selectCategory(_ category: Category) {
        commitEdits()
        guard var edited = item else { return }
        edited.category = category
        item = edited
        recordIdentificationCorrection(field: "category", item: edited)
    }

    func selectCondition(_ condition: Condition) {
        commitEdits()
        guard var edited = item else { return }
        edited.condition = condition
        item = edited
        recordIdentificationCorrection(field: "condition", item: edited)
    }

    func selectLikelyMatch(_ match: AnalyzeLikelyMatch) {
        guard let cleanMatch = match.sanitizedForDisplay() else { return }
        confirmedLikelyMatchName = cleanMatch.name
        nameText = cleanMatch.name
        commitEdits()
        if let item {
            recordIdentificationCorrection(field: "likely_match", item: item)
        }
        if let details = analysisDetails {
            analysisDetails = details.acceptingLikelyMatch(cleanMatch)
            analysisGuidance = analysisDetails?.displayHint
        }
    }

    func commitEdits(priceLocale: Locale = .current) {
        guard var edited = item else { return }
        let original = edited
        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty == false {
            edited.name = trimmedName
        }
        nameText = edited.name

        if let number = Self.priceDecimal(from: priceText, locale: priceLocale),
           let priceEstimate = Self.listingPriceEstimate(from: number) {
            edited.priceEstimate = priceEstimate
        }
        priceText = NSDecimalNumber(decimal: edited.priceEstimate).stringValue
        if edited.name != original.name,
           confirmedLikelyMatchName != edited.name {
            confirmedLikelyMatchName = nil
        }
        item = edited
        if edited != original {
            recordIdentificationCorrection(field: "manual_edit", item: edited)
        }
    }

    static func priceDecimal(from text: String, locale: Locale = .current) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let locales = [locale, Locale(identifier: "en_US_POSIX")]
        for candidate in locales {
            for style in [NumberFormatter.Style.currency, .decimal] {
                let formatter = NumberFormatter()
                formatter.locale = candidate
                formatter.numberStyle = style
                formatter.generatesDecimalNumbers = true
                if let decimal = (formatter.number(from: trimmed) as? NSDecimalNumber)?.decimalValue {
                    return decimal
                }
            }
        }

        let sanitized = sanitizedPriceText(trimmed, locale: locale)
        return Decimal(string: sanitized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func sanitizedPriceText(_ text: String, locale: Locale) -> String {
        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        let allowedScalars = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "\(decimalSeparator).,-"))
        let filtered = String(text.unicodeScalars.filter { allowedScalars.contains($0) })

        return filtered
            .replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
            .replacingOccurrences(of: ",", with: "")
    }

    private static func listingPriceEstimate(from value: Decimal) -> Decimal? {
        guard value > 0 else { return nil }
        let rounded = value.rounded(scale: 0)
        return max(rounded, Decimal(1))
    }

    private static func imageSizeBucket(for byteCount: Int) -> String {
        switch byteCount {
        case ..<250_000:
            "under_250kb"
        case ..<1_000_000:
            "250kb_1mb"
        case ..<3_000_000:
            "1mb_3mb"
        default:
            "over_3mb"
        }
    }

    private func cancelStillWorkingTask() {
        stillWorkingTask?.cancel()
        stillWorkingTask = nil
    }

    private func recordIdentificationCorrection(field: String, item: DetectedItem) {
        ProductAnalytics.record(
            .identificationCorrected,
            properties: [
                "field": field,
                "category": item.category.rawValue,
                "condition": item.condition.rawValue,
                "price_bucket": Self.priceBucket(for: item.priceEstimate)
            ]
        )
    }

    private static func priceBucket(for price: Decimal) -> String {
        if price < 25 {
            return "under_25"
        }
        if price < 100 {
            return "25_to_99"
        }
        if price < 500 {
            return "100_to_499"
        }
        return "500_plus"
    }
}
