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
    var showStillWorking = false

    private let analyzeHandler: AnalyzeHandler
    private let stillWorkingDelayNanoseconds: UInt64
    private var analysisGeneration = 0

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
        phase = .loading
        showStillWorking = false
        item = nil

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: stillWorkingDelayNanoseconds)
            if phase == .loading, generation == analysisGeneration {
                showStillWorking = true
            }
        }

        do {
            let response = try await analyzeHandler(imageData, accessToken).validatedForDisplay()
            guard generation == analysisGeneration else { return }
            let detected = DetectedItem(
                name: response.name,
                category: Category(apiValue: response.category),
                condition: Condition(apiValue: response.condition),
                priceEstimate: response.currentPrice.rounded(scale: 0)
            )
            item = detected
            nameText = detected.name
            priceText = NSDecimalNumber(decimal: detected.priceEstimate).stringValue
            phase = .success
            AnalysisFeedback.performSuccess()
        } catch is CancellationError {
            guard generation == analysisGeneration else { return }
            phase = .failed(APIError.unknown.localizedDescription)
            AnalysisFeedback.performFailure()
        } catch {
            guard generation == analysisGeneration else { return }
            phase = .failed(APIError.userMessage(for: error))
            AnalysisFeedback.performFailure()
        }
    }

    func cycleCategory() {
        commitEdits()
        item?.category = item?.category.next() ?? .other
    }

    func cycleCondition() {
        commitEdits()
        item?.condition = item?.condition.next() ?? .good
    }

    func commitEdits(priceLocale: Locale = .current) {
        guard var edited = item else { return }
        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty == false {
            edited.name = trimmedName
        }
        if let number = Self.priceDecimal(from: priceText, locale: priceLocale), number > 0 {
            edited.priceEstimate = number.rounded(scale: 0)
            priceText = NSDecimalNumber(decimal: edited.priceEstimate).stringValue
        }
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
}
