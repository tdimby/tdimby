import Foundation

/// Your own Spotify API keys, entered once and kept on this device. Search
/// needs a real Spotify Web API token, which needs a registered app — see
/// developer.spotify.com/dashboard. Stored in UserDefaults for simplicity;
/// fine for a personal single-device app, but swap for Keychain before
/// shipping this to anyone else.
final class SpotifyCredentialsStore: ObservableObject {
    private static let clientIDKey = "musicrate.spotifyClientID"
    private static let clientSecretKey = "musicrate.spotifyClientSecret"

    @Published var clientID: String {
        didSet { UserDefaults.standard.set(clientID, forKey: Self.clientIDKey) }
    }
    @Published var clientSecret: String {
        didSet { UserDefaults.standard.set(clientSecret, forKey: Self.clientSecretKey) }
    }

    init() {
        clientID = UserDefaults.standard.string(forKey: Self.clientIDKey) ?? "50d4476c330d49b79d950dea008d27cc"
        clientSecret = UserDefaults.standard.string(forKey: Self.clientSecretKey) ?? "219d7f5afcc54d9eac25f26cfc9bc025"
    }

    var hasCredentials: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
