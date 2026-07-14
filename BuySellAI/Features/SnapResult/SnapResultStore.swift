import Observation
import Foundation

@MainActor
@Observable
final class SnapResultStore {
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

    init(imageData: Data) {
        self.imageData = imageData
    }

    func analyzeIfNeeded(accessToken: String?) async {
        guard phase == .idle else { return }
        await analyze(accessToken: accessToken)
    }

    func analyze(accessToken: String?) async {
        phase = .loading
        showStillWorking = false
        item = nil

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if phase == .loading {
                showStillWorking = true
            }
        }

        do {
            let response = try await APIClient.shared.analyze(image: imageData, accessToken: accessToken)
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
            Haptics.notify(.success)
        } catch {
            phase = .failed(error.localizedDescription)
            Haptics.notify(.error)
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

    func commitEdits() {
        guard var edited = item else { return }
        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty == false {
            edited.name = trimmedName
        }
        let cleanedPrice = priceText
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Decimal(string: cleanedPrice), number > 0 {
            edited.priceEstimate = number.rounded(scale: 0)
            priceText = NSDecimalNumber(decimal: edited.priceEstimate).stringValue
        }
        item = edited
    }
}

