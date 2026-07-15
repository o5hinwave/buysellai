import Foundation
import XCTest
@testable import BuySellAI

final class SupabaseAuthClientTests: XCTestCase {
    override func tearDown() {
        SupabaseAuthMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testAppleIdentityTokenExchangeBuildsSupabaseIdTokenRequestAndUsesServerUserID() async throws {
        let client = try makeClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.scheme, "https")
            XCTAssertEqual(components.host, "example.supabase.co")
            XCTAssertEqual(components.path, "/auth/v1/token")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "grant_type" })?.value, "id_token")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["provider"] as? String, "apple")
            XCTAssertEqual(json["id_token"] as? String, "apple-jwt")
            XCTAssertEqual(json["nonce"] as? String, "raw-nonce")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"access_token":"supabase-access","refresh_token":"refresh-token","user":{"id":"server-user","email":"person@example.com"}}"#.utf8))
        }

        let session = try await client.exchangeAppleIdentityToken(
            identityToken: "apple-jwt",
            nonce: "raw-nonce",
            appleUserID: "apple-user",
            email: nil
        )

        XCTAssertEqual(session.userID, "server-user")
        XCTAssertEqual(session.appleUserID, "apple-user")
        XCTAssertEqual(session.email, "person@example.com")
        XCTAssertEqual(session.accessToken, "supabase-access")
        XCTAssertEqual(session.refreshToken, "refresh-token")
    }

    func testAppleIdentityTokenExchangeFallsBackToAppleUserIDWhenServerUserIsMissing() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"access_token":"supabase-access","refresh_token":"refresh-token"}"#.utf8))
        }

        let session = try await client.exchangeAppleIdentityToken(
            identityToken: "apple-jwt",
            nonce: "raw-nonce",
            appleUserID: "apple-user",
            email: "person@example.com"
        )

        XCTAssertEqual(session.userID, "apple-user")
        XCTAssertEqual(session.appleUserID, "apple-user")
        XCTAssertEqual(session.email, "person@example.com")
        XCTAssertEqual(session.accessToken, "supabase-access")
        XCTAssertEqual(session.refreshToken, "refresh-token")
    }

    func testEmailSignInBuildsPasswordGrantRequest() async throws {
        let client = try makeClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.path, "/auth/v1/token")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "grant_type" })?.value, "password")
            XCTAssertEqual(request.timeoutInterval, 20)

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["email"] as? String, "person@example.com")
            XCTAssertEqual(json["password"] as? String, "secret")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"access_token":"email-access","refresh_token":"email-refresh","user":{"id":"user-123","email":"person@example.com"}}"#.utf8))
        }

        let session = try await client.signInWithEmail(email: "person@example.com", password: "secret")

        XCTAssertEqual(session.userID, "user-123")
        XCTAssertNil(session.appleUserID)
        XCTAssertEqual(session.email, "person@example.com")
        XCTAssertEqual(session.accessToken, "email-access")
        XCTAssertEqual(session.refreshToken, "email-refresh")
    }

    func testRefreshSessionBuildsRefreshTokenGrantAndPreservesIdentity() async throws {
        let client = try makeClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.path, "/auth/v1/token")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "grant_type" })?.value, "refresh_token")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["refresh_token"] as? String, "old-refresh")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"access_token":"new-access","refresh_token":"new-refresh","user":{"id":"server-user","email":"updated@example.com"}}"#.utf8))
        }
        let existing = AuthSession(
            userID: "server-user",
            email: "person@example.com",
            accessToken: "old-access",
            refreshToken: "old-refresh",
            appleUserID: "apple-user"
        )

        let session = try await client.refreshSession(existing)

        XCTAssertEqual(session.userID, "server-user")
        XCTAssertEqual(session.appleUserID, "apple-user")
        XCTAssertEqual(session.email, "updated@example.com")
        XCTAssertEqual(session.accessToken, "new-access")
        XCTAssertEqual(session.refreshToken, "new-refresh")
    }

    func testRefreshSessionKeepsExistingRefreshTokenWhenResponseOmitsReplacement() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"access_token":"new-access","user":{"id":"server-user"}}"#.utf8))
        }
        let existing = AuthSession(
            userID: "server-user",
            email: "person@example.com",
            accessToken: "old-access",
            refreshToken: "old-refresh",
            appleUserID: "apple-user"
        )

        let session = try await client.refreshSession(existing)

        XCTAssertEqual(session.userID, "server-user")
        XCTAssertEqual(session.appleUserID, "apple-user")
        XCTAssertEqual(session.email, "person@example.com")
        XCTAssertEqual(session.accessToken, "new-access")
        XCTAssertEqual(session.refreshToken, "old-refresh")
    }

    func testRefreshSessionWithoutRefreshTokenMapsToNotConfigured() async throws {
        let client = try makeClient { _ in
            XCTFail("Refresh session without a refresh token should not make a network request.")
            throw URLError(.badURL)
        }
        let existing = AuthSession(
            userID: "server-user",
            email: "person@example.com",
            accessToken: "old-access"
        )

        do {
            _ = try await client.refreshSession(existing)
            XCTFail("Expected missing refresh token to map to notConfigured")
        } catch {
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
    }

    func testRefreshSessionMalformedJSONMapsToDecodingError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"refresh_token":"missing access token"}"#.utf8))
        }

        do {
            _ = try await client.refreshSession(Self.refreshableSession)
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testRefreshSessionTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.refreshSession(Self.refreshableSession)
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testRefreshSessionRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            _ = try await client.refreshSession(Self.refreshableSession)
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testRefreshSessionNonSuccessStatusMapsToServerError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            _ = try await client.refreshSession(Self.refreshableSession)
            XCTFail("Expected server error")
        } catch {
            XCTAssertEqual(error as? APIError, .server(401))
        }
    }

    func testRefreshSessionTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: attempts == 1 ? 503 : 200,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = attempts == 1
                ? Data()
                : Data(#"{"access_token":"retry-access","refresh_token":"retry-refresh","user":{"id":"server-user","email":"updated@example.com"}}"#.utf8)
            return (response, data)
        }

        let session = try await client.refreshSession(Self.refreshableSession)

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(session.userID, "server-user")
        XCTAssertEqual(session.email, "updated@example.com")
        XCTAssertEqual(session.accessToken, "retry-access")
        XCTAssertEqual(session.refreshToken, "retry-refresh")
        XCTAssertEqual(session.appleUserID, "apple-user")
    }

    func testEmailSignInMalformedJSONMapsToDecodingError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"refresh_token":"missing access token"}"#.utf8))
        }

        do {
            _ = try await client.signInWithEmail(email: "person@example.com", password: "secret")
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testAppleIdentityTokenExchangeMalformedJSONMapsToDecodingError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"refresh_token":"missing access token"}"#.utf8))
        }

        do {
            _ = try await client.exchangeAppleIdentityToken(
                identityToken: "apple-jwt",
                nonce: "raw-nonce",
                appleUserID: "apple-user",
                email: nil
            )
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testEmailSignInTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.signInWithEmail(email: "person@example.com", password: "secret")
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testAppleIdentityTokenExchangeTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.exchangeAppleIdentityToken(
                identityToken: "apple-jwt",
                nonce: "raw-nonce",
                appleUserID: "apple-user",
                email: nil
            )
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testEmailSignInRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            _ = try await client.signInWithEmail(email: "person@example.com", password: "secret")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testAppleIdentityTokenExchangeRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            _ = try await client.exchangeAppleIdentityToken(
                identityToken: "apple-jwt",
                nonce: "raw-nonce",
                appleUserID: "apple-user",
                email: nil
            )
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testEmailSignInNonSuccessStatusMapsToServerError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            _ = try await client.signInWithEmail(email: "person@example.com", password: "wrong")
            XCTFail("Expected server error")
        } catch {
            XCTAssertEqual(error as? APIError, .server(401))
        }
    }

    func testEmailSignInTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: attempts == 1 ? 503 : 200,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = attempts == 1
                ? Data()
                : Data(#"{"access_token":"retry-access","refresh_token":"retry-refresh","user":{"id":"user-456","email":"person@example.com"}}"#.utf8)
            return (response, data)
        }

        let session = try await client.signInWithEmail(email: "person@example.com", password: "secret")

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(session.userID, "user-456")
        XCTAssertEqual(session.accessToken, "retry-access")
    }

    func testAppleIdentityTokenExchangeTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: attempts == 1 ? 503 : 200,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = attempts == 1
                ? Data()
                : Data(#"{"access_token":"retry-access","refresh_token":"retry-refresh","user":{"id":"server-user","email":"person@example.com"}}"#.utf8)
            return (response, data)
        }

        let session = try await client.exchangeAppleIdentityToken(
            identityToken: "apple-jwt",
            nonce: "raw-nonce",
            appleUserID: "apple-user",
            email: nil
        )

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(session.userID, "server-user")
        XCTAssertEqual(session.email, "person@example.com")
        XCTAssertEqual(session.accessToken, "retry-access")
    }

    private static var refreshableSession: AuthSession {
        AuthSession(
            userID: "server-user",
            email: "person@example.com",
            accessToken: "old-access",
            refreshToken: "old-refresh",
            appleUserID: "apple-user"
        )
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) throws -> SupabaseAuthClient {
        SupabaseAuthMockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SupabaseAuthMockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        return SupabaseAuthClient(session: session, config: config)
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

private final class SupabaseAuthMockURLProtocol: URLProtocol {
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
