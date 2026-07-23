import Foundation

enum LaunchArguments {
    static let resetAuth = "--reset-auth"
    static let resetTutorial = "--reset-tutorial"
    static let skipTutorial = "--skip-tutorial"
    static let resetPreferences = "--reset-preferences"
    static let resetHistory = "--reset-history"
    static let seedHistory = "--seed-history"
    static let seedLargeHistory = "--seed-large-history"
    static let uiTesting = "--ui-testing"
    static let uiTestingAnalyzeOffline = "--ui-testing-analyze-offline"
    static let uiTestingCameraDenied = "--ui-testing-camera-denied"
    static let uiTestingCameraReady = "--ui-testing-camera-ready"
    static let uiTestingCameraSampleCapture = "--ui-testing-camera-sample-capture"
    static let uiTestingGenerateOffline = "--ui-testing-generate-offline"
    static let uiTestingSignedIn = "--ui-testing-signed-in"
    static let uiTestingSlowHistoryLoad = "--ui-testing-slow-history-load"
    static let uiTestingStateProbe = "--ui-testing-state-probe"
    static let uiTestingVerifyClipboard = "--ui-testing-verify-clipboard"

    static var isUITesting: Bool {
        contains(uiTesting)
    }

    static func contains(_ argument: String) -> Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains(argument)
#else
        false
#endif
    }
}
