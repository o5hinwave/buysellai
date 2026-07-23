import XCTest
@testable import BuySellAI

final class HistoryDeletionFeedbackTests: XCTestCase {
    func testHistoryDeletionFeedbackUsesWarningNotification() {
        XCTAssertEqual(HistoryDeletionFeedback.notificationType, .warning)
    }

    func testHistorySwipeDeleteRequestsConfirmationWithLightFeedback() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)

        let helperStart = try XCTUnwrap(home.range(of: #"private func requestDeleteConfirmation(for entry: HistoryEntry) {"#))
        let helperRemainder = home[helperStart.lowerBound...]
        let helperEnd = try XCTUnwrap(helperRemainder.range(of: #"private var deleteConfirmationBinding"#))
        let helperSource = String(helperRemainder[..<helperEnd.lowerBound])

        XCTAssertNotNil(home.range(of: #".swipeActions(edge: .trailing, allowsFullSwipe: false)"#))
        XCTAssertNotNil(home.range(of: #"requestDeleteConfirmation(for: entry)"#))
        XCTAssertNotNil(helperSource.range(of: #"Haptics.impact(.light)"#))
        XCTAssertNotNil(helperSource.range(of: #"pendingDeletion = entry"#))
    }

    func testConfirmedSwipeDeletePerformsImmediateWarningFeedbackAndSuppressesDuplicateStoreFeedback() throws {
        let home = try String(contentsOf: projectURL("BuySellAI/Features/Home/HomeView.swift"), encoding: .utf8)
        let confirmStart = try XCTUnwrap(home.range(of: #"private func confirmDelete() {"#))
        let confirmSource = String(home[confirmStart.lowerBound..<home.endIndex])

        XCTAssertNotNil(confirmSource.range(of: #"guard let pendingDeletion else { return }"#))
        XCTAssertNotNil(confirmSource.range(of: #"HistoryDeletionFeedback.perform()"#))
        XCTAssertNotNil(confirmSource.range(of: #"appStore.deleteHistory(pendingDeletion, emitsFeedback: false)"#))
        XCTAssertNotNil(confirmSource.range(of: #"self.pendingDeletion = nil"#))
    }

    func testDeleteHistoryPerformsWarningFeedbackByDefaultAfterSuccessfulDeletion() throws {
        let appStore = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)

        XCTAssertNotNil(appStore.range(of: #"func deleteHistory(_ entry: HistoryEntry, emitsFeedback: Bool = true)"#))
        XCTAssertGreaterThanOrEqual(appStore.components(separatedBy: "if emitsFeedback {\n                        HistoryDeletionFeedback.perform()").count - 1, 1)
        XCTAssertGreaterThanOrEqual(appStore.components(separatedBy: "if emitsFeedback {\n                HistoryDeletionFeedback.perform()").count - 1, 2)
        XCTAssertNotNil(appStore.range(of: #"try await store.remoteHistoryClient.deleteHistory(id: entry.id, accessToken: accessToken)"#))
        XCTAssertNotNil(appStore.range(of: #"try modelContext.save()"#))
        XCTAssertNotNil(appStore.range(of: #"history.removeAll { $0.id == entry.id }"#))
    }

    func testClearHistoryUsesSharedSuccessfulDeletionFeedback() throws {
        let appStore = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)
        let clearStart = try XCTUnwrap(appStore.range(of: #"func clearHistory() {"#))
        let reopenStart = try XCTUnwrap(appStore.range(of: #"func reopenListing(_ entry: HistoryEntry)"#, range: clearStart.upperBound..<appStore.endIndex))
        let clearSource = String(appStore[clearStart.lowerBound..<reopenStart.lowerBound])

        XCTAssertNotNil(clearSource.range(of: #"completeHistoryClear()"#))
        XCTAssertNotNil(clearSource.range(of: #"private func completeHistoryClear() {"#))
        XCTAssertNotNil(clearSource.range(of: #"history.removeAll()"#))
        XCTAssertNotNil(clearSource.range(of: #"HistoryDeletionFeedback.perform()"#))
        XCTAssertNotNil(clearSource.range(of: #"showToast("History cleared.".localized, style: .success)"#))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
