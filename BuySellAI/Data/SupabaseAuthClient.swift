import Foundation

actor SupabaseAuthClient {
    private let session: URLSession
    private let injectedConfig: AppConfig?

    init(session: URLSession? = nil, config: AppConfig? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 20
            self.session = URLSession(configuration: configuration)
        }
        self.injectedConfig = config
    }

    func exchangeAppleIdentityToken(
        identityToken: String,
        authorizationCode: String? = nil,
        nonce: String?,
        appleUserID: String,
        email: String?
    ) async throws -> AuthSession {
        let config = try loadConfig()
        let payload = AppleIDTokenRequest(provider: "apple", idToken: identityToken, nonce: nonce)
        let response = try await tokenRequest(grantType: "id_token", body: payload, config: config)
        let session = AuthSession(
            userID: response.user?.id ?? appleUserID,
            email: email ?? response.user?.email,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            appleUserID: appleUserID
        )
        if let authorizationCode, authorizationCode.isEmpty == false {
            try await storeAppleAuthorizationCode(
                authorizationCode,
                appleUserID: appleUserID,
                accessToken: response.accessToken,
                config: config
            )
        }
        return session
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthSession {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.isEmpty == false, password.isEmpty == false else {
            throw APIError.decoding
        }
        let payload = PasswordTokenRequest(email: trimmedEmail, password: password)
        let response = try await tokenRequest(grantType: "password", body: payload)
        return AuthSession(
            userID: response.user?.id ?? trimmedEmail,
            email: response.user?.email ?? trimmedEmail,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
    }

    func refreshSession(_ session: AuthSession) async throws -> AuthSession {
        guard let refreshToken = session.refreshToken, refreshToken.isEmpty == false else {
            throw APIError.notConfigured
        }
        let payload = RefreshTokenRequest(refreshToken: refreshToken)
        let response: SupabaseTokenResponse
        do {
            response = try await tokenRequest(grantType: "refresh_token", body: payload)
        } catch APIError.server(let code) where code == 401 || code == 403 {
            throw APIError.sessionExpired
        }
        return AuthSession(
            userID: session.userID,
            email: response.user?.email ?? session.email,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? session.refreshToken,
            appleUserID: session.appleUserID
        )
    }

    private func tokenRequest<Body: Encodable>(
        grantType: String,
        body: Body,
        config injectedConfig: AppConfig? = nil
    ) async throws -> SupabaseTokenResponse {
        let config = try injectedConfig ?? loadConfig()
        let url = try authURL(config: config, grantType: grantType)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.supabaseAuth.encode(body)
        return try await perform(request, decoding: SupabaseTokenResponse.self)
    }

    private func storeAppleAuthorizationCode(
        _ authorizationCode: String,
        appleUserID: String,
        accessToken: String,
        config: AppConfig
    ) async throws {
        let url = config.functionsBaseURL.appending(path: "store-apple-token")
        let payload = AppleTokenStoreRequest(authorizationCode: authorizationCode, appleUserID: appleUserID)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.supabaseAuth.encode(payload)
        try await performVoid(request)
    }

    private func loadConfig() throws -> AppConfig {
        if let injectedConfig {
            return injectedConfig
        }
        return try AppConfig.load()
    }

    private func authURL(config: AppConfig, grantType: String) throws -> URL {
        var components = URLComponents(
            url: config.supabaseURL.appending(path: "auth").appending(path: "v1").appending(path: "token"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "grant_type", value: grantType)]
        guard let url = components?.url else {
            throw APIError.unknown
        }
        return url
    }

    private func perform<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        do {
            return try await send(request, decoding: decoding)
        } catch APIError.server(let code) where (500...599).contains(code) {
            return try await sendMapped(request, decoding: decoding)
        } catch let error as URLError where error.code == .networkConnectionLost {
            return try await sendMapped(request, decoding: decoding)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            try APIError.rethrowCancellation(error)
            throw APIError.mapTransport(error)
        }
    }

    private func sendMapped<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        do {
            return try await send(request, decoding: decoding)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            try APIError.rethrowCancellation(error)
            throw APIError.mapTransport(error)
        }
    }

    private func send<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }
        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try JSONDecoder.supabaseAuth.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding
            }
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.server(httpResponse.statusCode)
        }
    }

    private func performVoid(_ request: URLRequest) async throws {
        do {
            try await sendVoid(request)
        } catch APIError.server(let code) where (500...599).contains(code) {
            try await sendVoidMapped(request)
        } catch let error as URLError where error.code == .networkConnectionLost {
            try await sendVoidMapped(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            try APIError.rethrowCancellation(error)
            throw APIError.mapTransport(error)
        }
    }

    private func sendVoidMapped(_ request: URLRequest) async throws {
        do {
            try await sendVoid(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            try APIError.rethrowCancellation(error)
            throw APIError.mapTransport(error)
        }
    }

    private func sendVoid(_ request: URLRequest) async throws {
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 409:
            throw APIError.accountAlreadyLinked
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.server(httpResponse.statusCode)
        }
    }

}

private struct AppleIDTokenRequest: Encodable {
    let provider: String
    let idToken: String
    let nonce: String?
}

private struct AppleTokenStoreRequest: Encodable {
    let authorizationCode: String
    let appleUserID: String
}

private struct PasswordTokenRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

private struct SupabaseTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let user: SupabaseUser?
}

private struct SupabaseUser: Decodable {
    let id: String
    let email: String?
}

private extension JSONEncoder {
    static var supabaseAuth: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

private extension JSONDecoder {
    static var supabaseAuth: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
