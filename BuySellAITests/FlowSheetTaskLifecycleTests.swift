import XCTest

final class FlowSheetTaskLifecycleTests: XCTestCase {
    func testListingRegenerateTaskIsOwnedAndCancelledWithSheet() throws {
        let listing = try String(contentsOf: projectURL("BuySellAI/Features/Listing/ListingSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(listing.range(of: "@State private var generationTask: Task<Void, Never>?"))
        XCTAssertNotNil(listing.range(of: "@State private var generationTaskID = UUID()"))
        XCTAssertNotNil(listing.range(of: "generationTask = Task { @MainActor in"))
        XCTAssertNotNil(listing.range(of: "guard Task.isCancelled == false, generationTaskID == taskID else { return }"))
        XCTAssertNotNil(listing.range(of: ".onDisappear {\n            cancelGenerationTask()\n        }"))
        XCTAssertNotNil(listing.range(of: "private func cancelGenerationTask()"))
        XCTAssertNil(listing.range(of: "Task { await store.generate(accessToken: await appStore.authenticatedAccessToken()) }"))
        XCTAssertNil(listing.range(of: "Task { @MainActor in\n            try? await Task.sleep(nanoseconds: 260_000_000)"))
    }

    func testSnapResultManualAnalysisTasksAreOwnedAndCancelledWithSheet() throws {
        let snapResult = try String(contentsOf: projectURL("BuySellAI/Features/SnapResult/SnapResultSheet.swift"), encoding: .utf8)

        XCTAssertNotNil(snapResult.range(of: "@State private var analysisTask: Task<Void, Never>?"))
        XCTAssertNotNil(snapResult.range(of: "@State private var analysisTaskID = UUID()"))
        XCTAssertNotNil(snapResult.range(of: "@State private var isSheetVisible = true"))
        XCTAssertNotNil(snapResult.range(of: "guard isSheetVisible,"))
        XCTAssertNotNil(snapResult.range(of: "analysisTask = Task { @MainActor in"))
        XCTAssertNotNil(snapResult.range(of: "guard Task.isCancelled == false, analysisTaskID == taskID else { return }"))
        XCTAssertNotNil(snapResult.range(of: ".onDisappear {\n            isSheetVisible = false\n            cancelAnalysisTask()\n        }"))
        XCTAssertNotNil(snapResult.range(of: "private func cancelAnalysisTask()"))
        XCTAssertNil(snapResult.range(of: "Task { await store.analyze(accessToken: await appStore.authenticatedAccessToken()) }"))
        XCTAssertNil(snapResult.range(of: "Task {\n            await store.analyzeIfNeeded(accessToken: await appStore.authenticatedAccessToken())\n        }"))
    }

    func testAppStoreDelayedPresentationAndSessionResetTasksAreOwnedAndCancelled() throws {
        let appStore = try String(contentsOf: projectURL("BuySellAI/App/AppRouter.swift"), encoding: .utf8)

        XCTAssertNotNil(appStore.range(of: "@ObservationIgnored private var modalPresentationTask: Task<Void, Never>?"))
        XCTAssertNotNil(appStore.range(of: "@ObservationIgnored private var flowTransitionTask: Task<Void, Never>?"))
        XCTAssertNotNil(appStore.range(of: "@ObservationIgnored private var sessionResetHistoryTask: Task<Void, Never>?"))
        XCTAssertNotNil(appStore.range(of: "@ObservationIgnored private var remoteHistoryMutationTasks: [UUID: Task<Void, Never>] = [:]"))
        XCTAssertNotNil(appStore.range(of: "modalPresentationTask?.cancel()"))
        XCTAssertNotNil(appStore.range(of: "flowTransitionTask?.cancel()"))
        XCTAssertNotNil(appStore.range(of: "sessionResetHistoryTask?.cancel()"))
        XCTAssertNotNil(appStore.range(of: "cancelRemoteHistoryMutationTasks()"))
        XCTAssertGreaterThanOrEqual(appStore.components(separatedBy: "modalPresentationTask = Task { @MainActor [weak self] in").count - 1, 2)
        XCTAssertNotNil(appStore.range(of: "flowTransitionTask = Task { @MainActor [weak self] in"))
        XCTAssertNotNil(appStore.range(of: "private func scheduleSessionResetHistoryLoad()"))
        XCTAssertNotNil(appStore.range(of: "sessionResetHistoryTask = Task { @MainActor [weak self] in"))
        XCTAssertNotNil(appStore.range(of: "private func scheduleRemoteHistoryMutation("))
        XCTAssertNotNil(appStore.range(of: "remoteHistoryMutationTasks[id] = Task { @MainActor [weak self] in"))
        XCTAssertNotNil(appStore.range(of: "defer { self.remoteHistoryMutationTasks[id] = nil }"))
        XCTAssertNotNil(appStore.range(of: "remoteHistoryMutationTasks.values.forEach { $0.cancel() }"))
        XCTAssertNotNil(appStore.range(of: "remoteHistoryMutationTasks.removeAll()"))
        XCTAssertGreaterThanOrEqual(appStore.components(separatedBy: "scheduleSessionResetHistoryLoad()").count - 1, 3)
        XCTAssertEqual(appStore.components(separatedBy: "scheduleRemoteHistoryMutation { store in").count - 1, 3)
        XCTAssertGreaterThanOrEqual(appStore.components(separatedBy: "cancelRemoteHistoryMutationTasks()").count - 1, 4)
        XCTAssertNil(appStore.range(of: "Task { await loadHistory() }"))
        XCTAssertNil(appStore.range(of: "Task {\n                do {\n                    guard let accessToken = try await authenticatedAccessTokenForSignedRequest()"))
        XCTAssertNil(appStore.range(of: "Task { @MainActor in\n            try? await Task.sleep(nanoseconds: flowTransitionDelayNanoseconds)"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
