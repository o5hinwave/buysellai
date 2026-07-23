import Observation
import Foundation

@MainActor
@Observable
final class SnapResultStore {
    typealias AnalyzeHandler = (Data, String?) async throws -> AnalyzeResponse

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
    var showStillWorking = false

    private let analyzeHandler: AnalyzeHandler
    private let stillWorkingDelayNanoseconds: UInt64
    private var analysisGeneration = 0
    private var stillWorkingTask: Task<Void, Never>?

    init(
        imageData: Data,
        stillWorkingDelayNanoseconds: UInt64 = 6_000_000_000,
        analyzeHandler: @escaping AnalyzeHandler = { imageData, accessToken in
            try await APIClient.shared.analyze(image: imageData, accessToken: accessToken)
        }
    ) {
        self.imageData = imageData
        self.stillWorkingDelayNanoseconds = stillWorkingDelayNanoseconds
        self.analyzeHandler = analyzeHandler
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

        stillWorkingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: stillWorkingDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            if phase == .loading, generation == analysisGeneration {
                showStillWorking = true
            }
        }

        do {
            let response = try await analyzeHandler(imageData, accessToken).validatedForDisplay()
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
            analysisGuidance = response.analysis?.displayHint
            phase = .success
            AnalysisFeedback.performSuccess()
        } catch let error where APIError.isCancellation(error) {
            guard generation == analysisGeneration else { return }
            cancelStillWorkingTask()
            phase = .idle
            showStillWorking = false
        } catch {
            guard generation == analysisGeneration else { return }
            cancelStillWorkingTask()
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
    }

    func cycleCondition() {
        commitEdits()
        guard var edited = item else { return }
        edited.condition = edited.condition.next()
        item = edited
    }

    func selectCategory(_ category: Category) {
        commitEdits()
        guard var edited = item else { return }
        edited.category = category
        item = edited
    }

    func selectCondition(_ condition: Condition) {
        commitEdits()
        guard var edited = item else { return }
        edited.condition = condition
        item = edited
    }

    func commitEdits(priceLocale: Locale = .current) {
        guard var edited = item else { return }
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
        item = edited
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

    private func cancelStillWorkingTask() {
        stillWorkingTask?.cancel()
        stillWorkingTask = nil
    }
}
