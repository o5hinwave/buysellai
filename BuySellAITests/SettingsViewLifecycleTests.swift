import XCTest

final class SettingsViewLifecycleTests: XCTestCase {
    func testDeleteAccountTaskIsOwnedAndCancelledWithConfirmationView() throws {
        let settings = try String(contentsOf: projectURL("BuySellAI/Features/Settings/SettingsView.swift"), encoding: .utf8)
        let deleteViewRange = try XCTUnwrap(settings.range(of: "private struct DeleteAccountView"))
        let safariRange = try XCTUnwrap(settings.range(of: "private struct SafariDestination", range: deleteViewRange.upperBound..<settings.endIndex))
        let deleteView = String(settings[deleteViewRange.lowerBound..<safariRange.lowerBound])

        XCTAssertNotNil(deleteView.range(of: "@State private var deleteAccountTask: Task<Void, Never>?"))
        XCTAssertNotNil(deleteView.range(of: "deleteAccountTask = Task { @MainActor in"))
        XCTAssertNotNil(deleteView.range(of: "guard Task.isCancelled == false else { return }"))
        XCTAssertNotNil(deleteView.range(of: ".onDisappear {\n            deleteAccountTask?.cancel()\n            deleteAccountTask = nil\n        }"))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
