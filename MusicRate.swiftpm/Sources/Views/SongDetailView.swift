import SwiftUI

struct SongDetailView: View {
    let item: SpotifyItem
    /// If set, this view was reached from inside that group's feed - the
    /// "Average Rating"/"Ratings" sections show that group's numbers, and
    /// the rating picker below defaults to posting back to that same
    /// group. If nil, those sections show Worldwide, and the picker
    /// defaults to Private (see `RatingAudience`).
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

            Section(group.map { "\($0.name) Average" } ?? "Worldwide Average") {
                HStack {
                    StaticStarsView(rating: summary.average, size: 18)
                    Text(summaryText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Rate For") {
                Picker("Audience", selection: $audience) {
                    Text("Private (Just Me)").tag(RatingAudience.privateOnly)
                    Text("Worldwide").tag(RatingAudience.worldwide)
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
            } footer: {
                Text("Private ratings are only visible to you.")
            }

            if !ratings.isEmpty {
                Section(group.map { "\($0.name)'s Ratings" } ?? "Worldwide Ratings") {
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
        do {
            let groupID = group?.id ?? worldwideGroupID
            ratings = try await store.ratings(forSongID: item.spotifyID, groupID: groupID)
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
            myStars = 0
            myNote = ""
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
