import Foundation

actor AccountClient {
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

    func deleteAccount(accessToken: String) async throws {
        let config = try loadConfig()
        let url = config.functionsBaseURL.appending(path: "delete-account")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        try await performVoid(request)
    }

    private func loadConfig() throws -> AppConfig {
        if let injectedConfig {
            return injectedConfig
        }
        return try AppConfig.load()
    }

    private func performVoid(_ request: URLRequest) async throws {
        do {
            try await sendVoid(request)
        } catch APIError.server(let code) where (500...599).contains(code) {
            try await sendVoidMapped(request)
        } catch let error as URLError where error.code == .networkConnectionLost {
            try await sendVoidMapped(request)
        } catch {
            throw APIError.mapTransport(error)
        }
    }

    private func sendVoidMapped(_ request: URLRequest) async throws {
        do {
            try await sendVoid(request)
        } catch {
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
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.server(httpResponse.statusCode)
        }
    }

}
