import Foundation

enum SpotifyAuthError: LocalizedError {
    case missingCredentials
    case transportFailed(String)
    case httpError(Int)
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Add your Spotify API keys in Search settings first."
        case .transportFailed(let detail):
            return "Couldn't reach Spotify to authenticate: \(detail)"
        case .httpError(let status):
            return "Spotify's login server returned an error (HTTP \(status))."
        case .invalidCredentials:
            return "Spotify rejected those API keys (HTTP 400/401). Double-check the Client ID and Secret in Search settings — a stray space or truncated character is the usual cause."
        }
    }
}

/// Gets an app-only access token via Spotify's Client Credentials flow.
/// This kind of token can search the public catalog but can't see or act on
/// any person's account — no login screen needed, just the app's own keys.
actor SpotifyAuthService {
    static let shared = SpotifyAuthService()

    private var cachedToken: String?
    private var expiresAt: Date?

    func accessToken(clientID: String, clientSecret: String) async throws -> String {
        if let cachedToken, let expiresAt, expiresAt > Date() {
            return cachedToken
        }

        let trimmedID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !trimmedSecret.isEmpty else {
            throw SpotifyAuthError.missingCredentials
        }

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let basicAuth = Data("\(trimmedID):\(trimmedSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(basicAuth)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("grant_type=client_credentials".utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SpotifyAuthError.transportFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAuthError.transportFailed("no HTTP response")
        }
        guard http.statusCode != 400, http.statusCode != 401 else {
            throw SpotifyAuthError.invalidCredentials
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SpotifyAuthError.httpError(http.statusCode)
        }

        struct TokenResponse: Decodable {
            let accessToken: String
            let expiresIn: Int

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case expiresIn = "expires_in"
            }
        }

        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw SpotifyAuthError.httpError(http.statusCode)
        }

        cachedToken = decoded.accessToken
        expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expiresIn - 60))
        return decoded.accessToken
    }

    func invalidateCachedToken() {
        cachedToken = nil
        expiresAt = nil
    }
}
