import Foundation

/// Holds the signed-in Firebase session and the current user's profile
/// (Firestore doc at `users/{uid}`), and keeps the ID token fresh.
/// Firebase ID tokens expire hourly, so every authenticated call should go
/// through `validIDToken()` rather than reading a token directly.
@MainActor
final class AccountStore: ObservableObject {
    private static let refreshTokenKey = "musicrate.firebaseRefreshToken"

    @Published private(set) var userID: String?
    @Published var displayName: String = ""
    @Published private(set) var email: String = ""
    @Published var lastError: String?
    @Published private(set) var isRestoringSession = false

    private var idToken: String?
    private var expiresAt: Date?
    private var refreshToken: String? {
        didSet { UserDefaults.standard.set(refreshToken, forKey: Self.refreshTokenKey) }
    }

    var isSignedIn: Bool { userID != nil }

    func restoreSession() async {
        guard let savedRefreshToken = UserDefaults.standard.string(forKey: Self.refreshTokenKey) else { return }
        isRestoringSession = true
        defer { isRestoringSession = false }
        do {
            try await applyRefresh(savedRefreshToken)
            try await loadProfile()
        } catch {
            // A stale/revoked refresh token just means "not signed in anymore" - not an error to show.
            refreshToken = nil
        }
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        let session = try await FirebaseAuthService.signUp(email: email, password: password)
        apply(session)
        self.displayName = displayName
        self.email = email
        try await saveProfile()
    }

    func signIn(email: String, password: String) async throws {
        let session = try await FirebaseAuthService.signIn(email: email, password: password)
        apply(session)
        self.email = email
        try await loadProfile()
    }

    func signOut() {
        userID = nil
        idToken = nil
        expiresAt = nil
        refreshToken = nil
        displayName = ""
        email = ""
    }

    func updateDisplayName(_ name: String) async throws {
        displayName = name
        try await saveProfile()
    }

    /// Returns a not-expired ID token, transparently refreshing first if needed.
    func validIDToken() async throws -> String {
        if let idToken, let expiresAt, expiresAt > Date() {
            return idToken
        }
        guard let refreshToken else { throw FirebaseAuthError.apiError("not signed in") }
        try await applyRefresh(refreshToken)
        guard let refreshedToken = idToken else { throw FirebaseAuthError.apiError("refresh failed") }
        return refreshedToken
    }

    private func apply(_ session: FirebaseSession) {
        userID = session.userID
        idToken = session.idToken
        refreshToken = session.refreshToken
        expiresAt = session.expiresAt
    }

    private func applyRefresh(_ token: String) async throws {
        let session = try await FirebaseAuthService.refresh(refreshToken: token)
        apply(session)
    }

    private func saveProfile() async throws {
        guard let userID else { return }
        let token = try await validIDToken()
        try await FirestoreService.setDocument(
            path: "users/\(userID)",
            fields: ["displayName": displayName, "email": email],
            idToken: token
        )
    }

    private func loadProfile() async throws {
        guard let userID else { return }
        let token = try await validIDToken()
        if let doc = try await FirestoreService.getDocument(path: "users/\(userID)", idToken: token) {
            displayName = doc.fields["displayName"] as? String ?? ""
            email = doc.fields["email"] as? String ?? email
        }
    }
}
