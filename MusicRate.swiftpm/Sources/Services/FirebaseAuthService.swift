import Foundation

enum FirebaseAuthError: LocalizedError {
    case notConfigured
    case transportFailed(String)
    case apiError(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "MusicRate isn't connected to a Firebase project yet — add your API key in FirebaseConfig.swift."
        case .transportFailed(let detail):
            return "Couldn't reach Firebase: \(detail)"
        case .apiError(let message):
            return friendlyMessage(for: message)
        case .decodingFailed:
            return "Firebase returned something MusicRate couldn't understand."
        }
    }

    /// Firebase's auth error codes are short machine strings (e.g.
    /// "EMAIL_EXISTS", "INVALID_LOGIN_CREDENTIALS") — translate the common
    /// ones so the app doesn't show raw API codes to a person.
    private func friendlyMessage(for code: String) -> String {
        switch code {
        case "EMAIL_EXISTS":
            return "An account already exists for that email — try signing in instead."
        case "EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD":
            return "That email/password combination doesn't match an account."
        case "WEAK_PASSWORD : Password should be at least 6 characters":
            return "Password needs to be at least 6 characters."
        case "INVALID_EMAIL":
            return "That doesn't look like a valid email address."
        case "USER_DISABLED":
            return "This account has been disabled."
        default:
            return "Firebase rejected that (\(code))."
        }
    }
}

struct FirebaseSession {
    let userID: String
    let idToken: String
    let refreshToken: String
    let expiresAt: Date
    /// Only set right after a fresh Google sign-in, from Google's own
    /// profile data - used to pre-fill a brand-new account's profile.
    var suggestedDisplayName: String?
    var suggestedEmail: String?
}

/// Firebase Authentication's REST API (Identity Toolkit) for email/password
/// sign up, sign in, and refreshing an expired session — deliberately not
/// the Firebase iOS SDK, which pulls in a large dependency tree that's
/// risky to build inside Swift Playgrounds. Plain HTTPS + JSON instead,
/// same pattern as every other network call in this app.
enum FirebaseAuthService {
    private struct SignUpOrInResponse: Decodable {
        let localId: String
        let idToken: String
        let refreshToken: String
        let expiresIn: String
    }

    private struct RefreshResponse: Decodable {
        let user_id: String
        let id_token: String
        let refresh_token: String
        let expires_in: String
    }

    private struct ErrorEnvelope: Decodable {
        struct ErrorBody: Decodable { let message: String }
        let error: ErrorBody
    }

    static func signUp(email: String, password: String) async throws -> FirebaseSession {
        let response: SignUpOrInResponse = try await post(
            path: "accounts:signUp",
            body: ["email": email, "password": password, "returnSecureToken": true]
        )
        return session(from: response)
    }

    static func signIn(email: String, password: String) async throws -> FirebaseSession {
        let response: SignUpOrInResponse = try await post(
            path: "accounts:signInWithPassword",
            body: ["email": email, "password": password, "returnSecureToken": true]
        )
        return session(from: response)
    }

    static func refresh(refreshToken: String) async throws -> FirebaseSession {
        guard FirebaseConfig.isConfigured else { throw FirebaseAuthError.notConfigured }
        var request = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("grant_type=refresh_token&refresh_token=\(refreshToken)".utf8)

        let data = try await send(request)
        guard let response = try? JSONDecoder().decode(RefreshResponse.self, from: data) else {
            throw FirebaseAuthError.decodingFailed
        }
        return FirebaseSession(
            userID: response.user_id,
            idToken: response.id_token,
            refreshToken: response.refresh_token,
            expiresAt: Date().addingTimeInterval((TimeInterval(response.expires_in) ?? 3600) - 60)
        )
    }

    private static func session(from response: SignUpOrInResponse) -> FirebaseSession {
        FirebaseSession(
            userID: response.localId,
            idToken: response.idToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval((TimeInterval(response.expiresIn) ?? 3600) - 60)
        )
    }

    private static func post<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        guard FirebaseConfig.isConfigured else { throw FirebaseAuthError.notConfigured }
        var request = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/\(path)?key=\(FirebaseConfig.apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data = try await send(request)
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw FirebaseAuthError.decodingFailed
        }
        return decoded
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FirebaseAuthError.transportFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FirebaseAuthError.transportFailed("no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw FirebaseAuthError.apiError(envelope.error.message)
            }
            throw FirebaseAuthError.apiError("HTTP \(http.statusCode)")
        }
        return data
    }
}
