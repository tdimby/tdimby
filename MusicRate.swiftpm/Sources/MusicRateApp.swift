import SwiftUI

@main
struct MusicRateApp: App {
    @StateObject private var store = MusicStore()
    @StateObject private var displayNameStore = DisplayNameStore()
    @StateObject private var spotifyCredentials = SpotifyCredentialsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(displayNameStore)
                .environmentObject(spotifyCredentials)
                .task { await store.start() }
        }
    }
}
