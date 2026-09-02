import Foundation

/// Your Firebase project's public identifiers. Neither of these is a
/// secret — the API key just identifies which project a request is for;
/// Firestore's actual security rules (not this key) are what enforce who
/// can read/write what. Get both from Firebase Console → Project Settings
/// → General → "Your apps" → the web app's config snippet.
enum FirebaseConfig {
    static let apiKey = ""
    static let projectID = ""

    static var isConfigured: Bool {
        !apiKey.isEmpty && !projectID.isEmpty
    }
}
