import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var account: AccountStore
    @State private var nameDraft = ""
    @State private var feedItems: [FeedItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                Section("Your Name") {
                    TextField("Your name", text: $nameDraft)
                        .textInputAutocapitalization(.words)
                        .onSubmit { Task { try? await account.updateDisplayName(nameDraft) } }
                }

                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(account.email).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Ratings Given")
                        Spacer()
                        Text("\(store.myRatings.count)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Groups Joined")
                        Spacer()
                        Text("\(store.myGroups.count)").foregroundStyle(.secondary)
                    }
                    Button("Sign Out", role: .destructive) { account.signOut() }
                }

                if isLoading {
                    ProgressView()
                } else if feedItems.isEmpty {
                    Text("You haven't rated anything yet. Head to \"Search\" or \"Paste Link\" to get started.")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Your Ratings") {
                        ForEach(feedItems) { feedItem in
                            NavigationLink(value: feedItem.item) {
                                FeedItemRow(feedItem: feedItem)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationDestination(for: SpotifyItem.self) { item in
                SongDetailView(item: item, group: nil)
            }
            .task {
                nameDraft = account.displayName
                await load()
            }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        await store.refreshMyRatings()
        feedItems = await store.myFeedItems()
    }
}
