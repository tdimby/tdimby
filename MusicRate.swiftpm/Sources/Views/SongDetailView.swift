import SwiftUI

struct SongDetailView: View {
    let item: SpotifyItem
    let group: RatingGroup?

    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var displayNameStore: DisplayNameStore

    @State private var ratings: [Rating] = []
    @State private var summary = RatingSummary.empty
    @State private var myStars = 0
    @State private var myNote = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                SongRow(item: item)
                Link(destination: item.spotifyURL) {
                    Label("Open in Spotify", systemImage: "arrow.up.right.square")
                }
            }

            Section("Average Rating") {
                HStack {
                    StaticStarsView(rating: summary.average, size: 18)
                    Text(summaryText)
                        .foregroundStyle(.secondary)
                }
            }

            Section(group.map { "Rate for \($0.name)" } ?? "Rate for Everyone") {
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
            }

            if !ratings.isEmpty {
                Section("Ratings") {
                    ForEach(ratings) { rating in
                        RatingRow(rating: rating)
                    }
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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
            if let mine = ratings.first(where: { $0.userID == store.currentUserID }) {
                myStars = mine.stars
                myNote = mine.note ?? ""
            }
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
                group: group,
                displayName: displayNameStore.name
            )
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
