import SwiftUI

struct GroupDetailView: View {
    let group: RatingGroup

    @EnvironmentObject var store: MusicStore
    @State private var feedItems: [FeedItem] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showShareSheet = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Invite Code")
                    Spacer()
                    Text(group.inviteCode)
                        .font(.system(.body, design: .monospaced).weight(.bold))
                }
                ShareLink(item: "Join my MusicRate group \"\(group.name)\" with invite code \(group.inviteCode)!") {
                    Label("Share Invite", systemImage: "square.and.arrow.up")
                }
            }

            WeeklyPickSection(group: group)

            if isLoading {
                ProgressView()
            } else if feedItems.isEmpty {
                Text("No ratings in this group yet. Rate a song and choose \"\(group.name)\" as the audience.")
                    .foregroundStyle(.secondary)
            } else {
                Section("Recently Rated") {
                    ForEach(feedItems) { feedItem in
                        NavigationLink(value: feedItem.item) {
                            FeedItemRow(feedItem: feedItem)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationDestination(for: SpotifyItem.self) { item in
            SongDetailView(item: item, group: group)
        }
        .task { await load() }
        .refreshable { await load() }
        .alert(
            "MusicRate",
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            feedItems = try await store.feed(for: group)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
