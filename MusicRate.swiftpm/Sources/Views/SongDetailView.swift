import SwiftUI

struct SongDetailView: View {
    let item: SpotifyItem
    /// If set, this view was reached from inside that group's feed - the
    /// "Average Rating"/"Ratings" sections show that group's numbers, and
    /// the rating picker below defaults to posting back to that same
    /// group. If nil (reached from Search or Favorites), there's no
    /// shared audience to summarize, so those sections are hidden and the
    /// picker defaults to Private (see `RatingAudience`).
    let group: RatingGroup?

    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var account: AccountStore

    @State private var ratings: [Rating] = []
    @State private var summary = RatingSummary.empty
    @State private var myStars = 0
    @State private var myNote = ""
    @State private var audience: RatingAudience = .privateOnly
    @State private var isSubmitting = false
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                SongRow(item: item)
                Link(destination: item.spotifyURL) {
                    Label("Open in \(item.source.displayName)", systemImage: "arrow.up.right.square")
                }
                if item.source != .spotify {
                    Link(destination: SpotifyLinkParser.searchURL(for: "\(item.title) \(item.subtitle)")) {
                        Label("Search on Spotify", systemImage: "magnifyingglass")
                    }
                }
            }

            if let group {
                Section("\(group.name) Average") {
                    HStack {
                        StaticStarsView(rating: summary.average, size: 18)
                        Text(summaryText)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Picker("Audience", selection: $audience) {
                    Text("Private (Just Me)").tag(RatingAudience.privateOnly)
                    ForEach(store.myGroups) { group in
                        Text(group.name).tag(RatingAudience.group(group))
                    }
                }
                StarRatingView(rating: $myStars)
                TextField("Add a note (optional)", text: $myNote, axis: .vertical)
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit Rating")
                    }
                }
                .disabled(myStars == 0 || isSubmitting)
            } header: {
                Text("Rate For")
            } footer: {
                Text("Private ratings are only visible to you.")
            }

            if let group, !ratings.isEmpty {
                Section("\(group.name)'s Ratings") {
                    ForEach(ratings) { rating in
                        RatingRow(rating: rating)
                    }
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            audience = group.map(RatingAudience.group) ?? .privateOnly
            await load()
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

    private var summaryText: String {
        guard summary.count > 0 else { return "No ratings yet" }
        let unit = summary.count == 1 ? "rating" : "ratings"
        return String(format: "%.1f · %d %@", summary.average, summary.count, unit)
    }

    private func load() async {
        guard let group else { return }
        do {
            ratings = try await store.ratings(forSongID: item.spotifyID, groupID: group.id)
            summary = RatingSummary(ratings: ratings)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await store.submitRating(
                for: item,
                stars: myStars,
                note: myNote,
                audience: audience,
                displayName: account.displayName
            )
            Haptics.success()
            myStars = 0
            myNote = ""
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
