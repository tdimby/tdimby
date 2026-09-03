import SwiftUI

struct GroupDetailView: View {
    let group: RatingGroup

    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var account: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var feedItems: [FeedItem] = []
    @State private var members: [GroupMember] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showLeaveConfirmation = false
    @State private var isLeaving = false

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

            if !members.isEmpty {
                Section("Members (\(members.count))") {
                    ForEach(members) { member in
                        HStack {
                            Text(member.displayName)
                            if member.userID == group.ownerUserID {
                                Text("Owner")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if member.userID == account.userID {
                                Text("(You)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }

            WeeklyPickSection(group: group)

            if !topRated.isEmpty {
                Section {
                    ForEach(topRated, id: \.item.spotifyID) { entry in
                        NavigationLink(value: entry.item) {
                            SongRow(item: entry.item) {
                                StaticStarsView(rating: entry.average)
                            }
                        }
                    }
                } header: {
                    Text("Top Rated")
                } footer: {
                    Text("Based on this group's most recent ratings.")
                }
            }

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

            Section {
                Button(role: .destructive) {
                    showLeaveConfirmation = true
                } label: {
                    if isLeaving {
                        ProgressView()
                    } else {
                        Text("Leave Group")
                    }
                }
                .disabled(isLeaving)
            }
        }
        .navigationTitle(group.name)
        .navigationDestination(for: SpotifyItem.self) { item in
            SongDetailView(item: item, group: group)
        }
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog(
            "Leave \"\(group.name)\"?",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Group", role: .destructive) {
                Task { await leave() }
            }
        } message: {
            Text("You can rejoin later with the invite code.")
        }
        .alert(
            "MusicRate",
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private var topRated: [(item: SpotifyItem, average: Double, count: Int)] {
        let grouped = Dictionary(grouping: feedItems, by: { $0.item.spotifyID })
        return grouped.values
            .compactMap { items -> (item: SpotifyItem, average: Double, count: Int)? in
                guard let item = items.first?.item else { return nil }
                let stars = items.map(\.rating.stars)
                let average = Double(stars.reduce(0, +)) / Double(stars.count)
                return (item, average, stars.count)
            }
            .sorted { $0.average > $1.average }
            .prefix(5)
            .map { $0 }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        async let feedResult = store.feed(for: group)
        async let membersResult = store.members(of: group)
        do {
            feedItems = try await feedResult
            members = try await membersResult
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func leave() async {
        isLeaving = true
        defer { isLeaving = false }
        do {
            try await store.leaveGroup(group)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
