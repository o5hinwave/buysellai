import Foundation
import XCTest
@testable import BuySellAI

@MainActor
final class AuthStoreTests: XCTestCase {
    override func tearDown() {
        AuthStoreMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testEmailSignInRejectsDuplicateAttemptWhileRequestIsInFlight() async throws {
        let requestStarted = expectation(description: "email sign-in request started")
        let releaseRequest = DispatchSemaphore(value: 0)
        let requestCountQueue = DispatchQueue(label: "BuySellAI.AuthStoreTests.requestCount")
        var requestCount = 0

        let store = try makeStore { request in
            requestCountQueue.sync {
                requestCount += 1
            }

            requestStarted.fulfill()
            XCTAssertEqual(.success, releaseRequest.wait(timeout: .now() + 2))
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"access_token":"email-access","refresh_token":"email-refresh","user":{"id":"user-123","email":"person@example.com"}}"#.utf8))
        }
        store.email = "person@example.com"
        store.password = "secret"

        let firstSignIn = Task { try await store.signInWithEmail() }
        await fulfillment(of: [requestStarted], timeout: 1)

        XCTAssertTrue(store.isSigningIn)
        do {
            _ = try await store.signInWithEmail()
            XCTFail("Expected duplicate in-flight sign-in to be treated as cancellation.")
        } catch {
            XCTAssertTrue(error is CancellationError)
            XCTAssertNil(AuthErrorPresentation.message(for: error))
        }

        releaseRequest.signal()
        let session = try await firstSignIn.value

        XCTAssertEqual(session.userID, "user-123")
        XCTAssertFalse(store.isSigningIn)
        let finalRequestCount = requestCountQueue.sync { requestCount }
        XCTAssertEqual(finalRequestCount, 1)
    }

    func testEmailSignInTrimsEmailAndRejectsWhitespaceOnlyEmail() async throws {
        var observedEmail: String?
        let store = try makeStore { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            observedEmail = json["email"] as? String

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"access_token":"email-access","refresh_token":"email-refresh","user":{"id":"user-123","email":"person@example.com"}}"#.utf8))
        }

        store.email = " \n\t "
        store.password = "secret"
        XCTAssertFalse(store.canSubmitEmail)
        do {
            _ = try await store.signInWithEmail()
            XCTFail("Expected whitespace-only email to fail before making a request.")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
        XCTAssertNil(observedEmail)

        store.email = "  person@example.com \n"
        XCTAssertTrue(store.canSubmitEmail)
        let session = try await store.signInWithEmail()

        XCTAssertEqual(session.userID, "user-123")
        XCTAssertEqual(observedEmail, "person@example.com")
    }

    func testAuthViewDisablesEntryPointsDuringSignIn() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"PrimaryPillButton\(title: "Continue with Apple", systemImage: "apple.logo"\)[\s\S]*?\.disabled\(store\.isSigningIn\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"SecondaryPillButton\(title: "Continue with Email"[\s\S]*?\.disabled\(store\.isSigningIn\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"TextActionButton\(title: "Keep going without an account", minHeight: guestActionMinHeight\)[\s\S]*?\.disabled\(store\.isSigningIn\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"TextField\("Email"\.localized[\s\S]*?\.disabled\(store\.isSigningIn\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: #"SecureField\("Password"\.localized[\s\S]*?\.disabled\(store\.isSigningIn\)"#, options: .regularExpression))
        XCTAssertNotNil(source.range(of: ".disabled(store.canSubmitEmail == false)"))
        XCTAssertNotNil(source.range(of: "guard store.canSubmitEmail else { return }"))
    }

    func testAuthLandingKeepsGuestEscapeStickyAndDynamicTypeAware() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: #"@Environment(\.dynamicTypeSize) private var dynamicTypeSize"#))
        XCTAssertNotNil(source.range(of: #"private var providerActions: some View"#))
        XCTAssertNotNil(source.range(of: #"private var guestBottomAction: some View"#))
        XCTAssertNotNil(source.range(of: #".safeAreaInset(edge: .bottom)"#))
        XCTAssertNotNil(source.range(of: #".padding(.bottom, authBottomContentInset)"#))
        XCTAssertNotNil(source.range(of: #"TextActionButton(title: "Keep going without an account", minHeight: guestActionMinHeight)"#))
        XCTAssertNotNil(source.range(of: #".nativeMaterialBar(tintOpacity: 0.78)"#))
        XCTAssertNotNil(source.range(of: #"private var authBottomContentInset: CGFloat"#))
        XCTAssertNotNil(source.range(of: #"dynamicTypeSize.isAccessibilitySize ? 120 : 96"#))
        XCTAssertNotNil(source.range(of: #"private var guestActionMinHeight: CGFloat"#))
        XCTAssertNotNil(source.range(of: #"dynamicTypeSize.isAccessibilitySize ? 60 : 52"#))
    }

    func testAuthViewCancelsInFlightSignInTasksWhenViewsDisappear() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthView.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "@State private var appleSignInTask: Task<Void, Never>?"))
        XCTAssertNotNil(source.range(of: "guard appleSignInTask == nil else { return }"))
        XCTAssertNotNil(source.range(of: "appleSignInTask = Task { @MainActor in"))
        XCTAssertNotNil(source.range(of: "appleSignInTask?.cancel()"))
        XCTAssertNotNil(source.range(of: "appleSignInTask = nil"))

        XCTAssertNotNil(source.range(of: "@State private var emailSignInTask: Task<Void, Never>?"))
        XCTAssertNotNil(source.range(of: "guard emailSignInTask == nil else { return }"))
        XCTAssertNotNil(source.range(of: "emailSignInTask = Task { @MainActor in"))
        XCTAssertNotNil(source.range(of: "emailSignInTask?.cancel()"))
        XCTAssertNotNil(source.range(of: "emailSignInTask = nil"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "guard Task.isCancelled == false else { return }").count - 1, 4)
    }

    func testAppleSignInCoordinatorRetainsAuthorizationControllerUntilCompletion() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthStore.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "private var currentController: ASAuthorizationController?"))
        XCTAssertNotNil(source.range(of: "currentController = controller"))
        XCTAssertNotNil(source.range(of: "controller.performRequests()"))
        XCTAssertNotNil(source.range(
            of: #"private func resetInFlightAuthorization\(\) \{[\s\S]*?continuation = nil[\s\S]*?currentNonce = nil[\s\S]*?currentController = nil[\s\S]*?\}"#,
            options: .regularExpression
        ))
        XCTAssertNotNil(source.range(of: "finish(returning: AppleSignInResult("))
        XCTAssertNotNil(source.range(of: "finish(throwing: APIError.unknown)"))
        XCTAssertNotNil(source.range(of: "finish(throwing: error)"))
        XCTAssertNotNil(source.range(of: "finish(throwing: CancellationError())"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "resetInFlightAuthorization()").count - 1, 3)
    }

    func testAppleSignInCoordinatorCancelsContinuationAndClearsControllerReferences() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthStore.swift"), encoding: .utf8)

        XCTAssertNotNil(source.range(of: "withTaskCancellationHandler"))
        XCTAssertNotNil(source.range(of: "Task { @MainActor [weak self] in"))
        XCTAssertNotNil(source.range(of: "self?.cancelInFlightAuthorization()"))
        XCTAssertNotNil(source.range(of: "private func cancelInFlightAuthorization()"))
        XCTAssertNotNil(source.range(of: "finish(throwing: CancellationError())"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "Task.isCancelled").count - 1, 2)
        XCTAssertNotNil(source.range(of: "guard continuation == nil else {\n            throw CancellationError()\n        }"))
        XCTAssertNotNil(source.range(of: "private func finish(returning result: AppleSignInResult)"))
        XCTAssertNotNil(source.range(of: "private func finish(throwing error: Error)"))
        XCTAssertNotNil(source.range(of: "currentController?.delegate = nil"))
        XCTAssertNotNil(source.range(of: "currentController?.presentationContextProvider = nil"))
    }

    func testAppleSignInPresentationAnchorPrefersForegroundActiveScene() throws {
        let source = try String(contentsOf: projectURL("BuySellAI/Features/Auth/AuthStore.swift"), encoding: .utf8)
        let anchorStart = try XCTUnwrap(source.range(of: "func presentationAnchor(for controller: ASAuthorizationController)"))
        let nextSection = try XCTUnwrap(source.range(of: "private static func randomNonce", range: anchorStart.upperBound..<source.endIndex))
        let anchorSource = source[anchorStart.lowerBound..<nextSection.lowerBound]

        XCTAssertNotNil(anchorSource.range(of: ".filter { $0.activationState == .foregroundActive }"))
        XCTAssertNotNil(anchorSource.range(of: "activeWindows.first { $0.isKeyWindow }"))
        XCTAssertNotNil(anchorSource.range(of: "activeWindows.first"))
        XCTAssertNotNil(anchorSource.range(of: "scenes.flatMap(\\.windows).first { $0.isKeyWindow }"))
    }

    private func makeStore(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) throws -> AuthStore {
        AuthStoreMockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthStoreMockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        return AuthStore(supabaseAuthClient: SupabaseAuthClient(session: session, config: config))
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
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

private final class AuthStoreMockURLProtocol: URLProtocol {
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
