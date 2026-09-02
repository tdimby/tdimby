import SwiftUI

@main
struct MusicRateApp: App {
    @StateObject private var account: AccountStore
    @StateObject private var store: MusicStore
    @StateObject private var weeklyPickStore: WeeklyPickStore

    init() {
        let account = AccountStore()
        _account = StateObject(wrappedValue: account)
        _store = StateObject(wrappedValue: MusicStore(account: account))
        _weeklyPickStore = StateObject(wrappedValue: WeeklyPickStore(account: account))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(account)
                .environmentObject(store)
                .environmentObject(weeklyPickStore)
                .task { await account.restoreSession() }
        }
    }
}
