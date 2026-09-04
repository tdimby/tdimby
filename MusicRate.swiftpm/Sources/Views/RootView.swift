import SwiftUI

struct RootView: View {
    @EnvironmentObject var account: AccountStore
    @EnvironmentObject var store: MusicStore

    var body: some View {
        Group {
            if account.isRestoringSession {
                ProgressView()
            } else if account.isSignedIn {
                MainTabView()
                    .task(id: account.userID) {
                        await store.start()
                    }
            } else {
                SignInView()
            }
        }
        .alert(
            "MusicRate",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            GroupsView()
                .tabItem { Label("Groups", systemImage: "person.3.fill") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "heart.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
