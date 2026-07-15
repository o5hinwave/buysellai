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
        nonce: String?,
        appleUserID: String,
        email: String?
    ) async throws -> AuthSession {
        let payload = AppleIDTokenRequest(provider: "apple", idToken: identityToken, nonce: nonce)
        let response = try await tokenRequest(grantType: "id_token", body: payload)
        return AuthSession(
            userID: appleUserID,
            email: email ?? response.user?.email,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            appleUserID: appleUserID
        )
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthSession {
        let payload = PasswordTokenRequest(email: email, password: password)
        let response = try await tokenRequest(grantType: "password", body: payload)
        return AuthSession(
            userID: response.user?.id ?? email,
            email: response.user?.email ?? email,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
    }

    func refreshSession(_ session: AuthSession) async throws -> AuthSession {
        guard let refreshToken = session.refreshToken, refreshToken.isEmpty == false else {
            throw APIError.notConfigured
        }
        let payload = RefreshTokenRequest(refreshToken: refreshToken)
        let response = try await tokenRequest(grantType: "refresh_token", body: payload)
        return AuthSession(
            userID: session.userID,
            email: response.user?.email ?? session.email,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            appleUserID: session.appleUserID
        )
    }

    private func tokenRequest<Body: Encodable>(grantType: String, body: Body) async throws -> SupabaseTokenResponse {
        let config = try loadConfig()
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
        } catch {
            throw mapTransport(error)
        }
    }

    private func sendMapped<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        do {
            return try await send(request, decoding: decoding)
        } catch {
            throw mapTransport(error)
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

    private func mapTransport(_ error: Error) -> Error {
        if let error = error as? APIError {
            return error
        }
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return APIError.offline
            case .timedOut:
                return APIError.timeout
            default:
                return APIError.unknown
            }
        }
        return APIError.unknown
    }
}

private struct AppleIDTokenRequest: Encodable {
    let provider: String
    let idToken: String
    let nonce: String?
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
