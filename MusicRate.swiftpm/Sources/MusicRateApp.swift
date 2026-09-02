import SwiftUI

@main
struct MusicRateApp: App {
    @StateObject private var store = MusicStore()
    @StateObject private var displayNameStore = DisplayNameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(displayNameStore)
                .task { await store.start() }
        }
    }
}
