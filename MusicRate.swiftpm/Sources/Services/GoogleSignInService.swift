import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum GoogleSignInError: LocalizedError {
    case notConfigured
    case authSessionFailed(String)
    case missingCode
    case tokenExchangeFailed
    case firebaseExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Sign-In isn't set up yet — add your iOS OAuth Client ID in GoogleAuthConfig.swift."
        case .authSessionFailed(let detail):
            return "Google sign-in didn't complete: \(detail)"
        case .missingCode:
            return "Google didn't return an authorization code."
        case .tokenExchangeFailed:
            return "Couldn't exchange the Google authorization code for a token."
        case .firebaseExchangeFailed(let detail):
            return "Firebase rejected the Google sign-in: \(detail)"
        }
    }
}

/// Google Sign-In without the Google SDK: a hand-rolled OAuth 2.0
/// Authorization Code + PKCE flow via `ASWebAuthenticationSession` (an
/// Apple framework already built into iOS, no package dependency), then
/// exchanging the resulting Google ID token with Firebase's REST API
/// (`accounts:signInWithIdp`) for a normal Firebase session - same
/// `FirebaseSession` type email/password sign-in produces.
enum GoogleSignInService {
    private static let redirectPath = "oauth2redirect"

    @MainActor
    static func signIn() async throws -> FirebaseSession {
        guard GoogleAuthConfig.isConfigured else { throw GoogleSignInError.notConfigured }

        let codeVerifier = randomURLSafeString(length: 64)
        let codeChallenge = codeChallenge(for: codeVerifier)
        let state = randomURLSafeString(length: 16)
        let redirectURI = "\(GoogleAuthConfig.redirectScheme):/\(redirectPath)"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleAuthConfig.iOSClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]

        let callbackURL = try await authenticate(url: components.url!, callbackScheme: GoogleAuthConfig.redirectScheme)

        guard
            let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let returnedState = callbackComponents.queryItems?.first(where: { $0.name == "state" })?.value,
            returnedState == state,
            let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw GoogleSignInError.missingCode }

        let googleIDToken = try await exchangeCodeForIDToken(code: code, codeVerifier: codeVerifier, redirectURI: redirectURI)
        return try await exchangeWithFirebase(googleIDToken: googleIDToken)
    }

    @MainActor
    private static func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        // presentationContextProvider is a weak reference, so contextProvider
        // must be kept alive some other way until the session completes -
        // capturing it in the completion closure (below) does that.
        let contextProvider = PresentationContextProvider()
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                _ = contextProvider
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: GoogleSignInError.authSessionFailed(error?.localizedDescription ?? "cancelled"))
                }
            }
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }
    }

    private static func exchangeCodeForIDToken(code: String, codeVerifier: String, redirectURI: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleAuthConfig.iOSClientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { throw GoogleSignInError.tokenExchangeFailed }

        struct TokenResponse: Decodable {
            let idToken: String
            enum CodingKeys: String, CodingKey { case idToken = "id_token" }
        }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw GoogleSignInError.tokenExchangeFailed
        }
        return decoded.idToken
    }

    private static func exchangeWithFirebase(googleIDToken: String) async throws -> FirebaseSession {
        guard FirebaseConfig.isConfigured else { throw FirebaseAuthError.notConfigured }
        var request = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(FirebaseConfig.apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let postBody = "id_token=\(googleIDToken)&providerId=google.com"
        let body: [String: Any] = [
            "postBody": postBody,
            "requestUri": "https://\(FirebaseConfig.projectID).firebaseapp.com",
            "returnSecureToken": true
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            throw GoogleSignInError.firebaseExchangeFailed("no response")
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
                ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)"
            throw GoogleSignInError.firebaseExchangeFailed(message)
        }

        struct IdpSignInResponse: Decodable {
            let localId: String
            let idToken: String
            let refreshToken: String
            let expiresIn: String
            let email: String?
            let displayName: String?
        }
        guard let decoded = try? JSONDecoder().decode(IdpSignInResponse.self, from: data) else {
            throw GoogleSignInError.firebaseExchangeFailed("couldn't parse Firebase's response")
        }

        return FirebaseSession(
            userID: decoded.localId,
            idToken: decoded.idToken,
            refreshToken: decoded.refreshToken,
            expiresAt: Date().addingTimeInterval((TimeInterval(decoded.expiresIn) ?? 3600) - 60),
            suggestedDisplayName: decoded.displayName,
            suggestedEmail: decoded.email
        )
    }

    // MARK: - PKCE helpers

    private static func randomURLSafeString(length: Int) -> String {
        let bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return Data(hashed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
