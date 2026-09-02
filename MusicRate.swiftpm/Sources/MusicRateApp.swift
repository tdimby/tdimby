import SwiftUI

@main
struct MusicRateApp: App {
    @StateObject private var account: AccountStore
    @StateObject private var store: MusicStore

    init() {
        let account = AccountStore()
        _account = StateObject(wrappedValue: account)
        _store = StateObject(wrappedValue: MusicStore(account: account))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(account)
                .environmentObject(store)
                .task { await account.restoreSession() }
        }
    }
}
