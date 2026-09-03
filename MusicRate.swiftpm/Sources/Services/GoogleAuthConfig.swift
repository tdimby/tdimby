import Foundation

/// Your Google OAuth "iOS" client, from console.cloud.google.com (the same
/// Google Cloud project your Firebase project lives in) → APIs & Services
/// → Credentials → Create Credentials → OAuth client ID → Application
/// type: iOS → Bundle ID must match Package.swift's `bundleIdentifier`
/// exactly ("com.example.musicrate"). Not the "Web client" Firebase
/// auto-created when you turned on Google sign-in - that one has a client
/// secret, which a native app has no safe place to hold; this one doesn't
/// need a secret at all.
enum GoogleAuthConfig {
    static let iOSClientID = ""

    /// Google's "reversed client ID" convention, e.g. a client ID of
    /// "1234-abcd.apps.googleusercontent.com" becomes
    /// "com.googleusercontent.apps.1234-abcd". This MUST also be pasted
    /// into AdditionalInfo.plist's CFBundleURLSchemes entry — Swift can
    /// compute it here for building URLs at runtime, but Info.plist has no
    /// way to reference Swift code, so the two have to be kept in sync by
    /// hand.
    static var redirectScheme: String {
        let parts = iOSClientID.split(separator: ".")
        guard parts.count >= 3 else { return "" }
        return parts.reversed().joined(separator: ".")
    }

    static var isConfigured: Bool {
        !iOSClientID.isEmpty
    }
}
