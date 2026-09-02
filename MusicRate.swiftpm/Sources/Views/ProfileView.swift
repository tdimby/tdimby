import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var displayNameStore: DisplayNameStore
    @State private var feedItems: [FeedItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                Section("Your Name") {
                    TextField("Your name", text: $displayNameStore.name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    HStack {
                        Text("iCloud Status")
                        Spacer()
                        Text(store.isSignedInToiCloud ? "Signed In" : "Not Signed In")
                            .foregroundStyle(store.isSignedInToiCloud ? .green : .red)
                    }
                    HStack {
                        Text("Ratings Given")
                        Spacer()
                        Text("\(store.myRatings.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Groups Joined")
                        Spacer()
                        Text("\(store.myGroups.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                if isLoading {
                    ProgressView()
                } else if feedItems.isEmpty {
                    Text("You haven't rated anything yet. Head to \"Add & Rate\" to get started.")
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
            .task { await load() }
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
