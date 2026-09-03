import SwiftUI

struct WeeklyPickSection: View {
    let group: RatingGroup
    @EnvironmentObject var weeklyPickStore: WeeklyPickStore
    @State private var showSubmitSheet = false

    var body: some View {
        Section("Song of the Week") {
            if weeklyPickStore.isLoading && weeklyPickStore.currentRound == nil {
                ProgressView()
            } else if let round = weeklyPickStore.currentRound {
                if round.isResolved {
                    if
                        let winningID = round.winningSubmissionID,
                        let winner = weeklyPickStore.submissionSummaries.first(where: { $0.id == winningID })
                    {
                        WinnerRow(summary: winner)
                    } else {
                        Text("This round ended with no ratings, so there's no winner.")
                            .foregroundStyle(.secondary)
                    }
                    Button("Start Next Week's Round") {
                        Task { try? await weeklyPickStore.startNewRound(for: group) }
                    }
                } else {
                    ForEach(weeklyPickStore.submissionSummaries) { summary in
                        SubmissionRow(summary: summary)
                    }
                    Button {
                        showSubmitSheet = true
                    } label: {
                        Label("Submit a Song", systemImage: "plus.circle")
                    }
                    if !weeklyPickStore.submissionSummaries.isEmpty {
                        Button("Close Round & Reveal Winner") {
                            Task { try? await weeklyPickStore.closeRound(round) }
                        }
                    }
                }
            } else {
                Text("No round yet this week — start one and everyone can submit a song.")
                    .foregroundStyle(.secondary)
                Button("Start This Week's Round") {
                    Task { try? await weeklyPickStore.startNewRound(for: group) }
                }
            }

            if !weeklyPickStore.leaderboard.isEmpty {
                DisclosureGroup("Leaderboard") {
                    ForEach(weeklyPickStore.leaderboard) { entry in
                        HStack {
                            Text(entry.name)
                            Spacer()
                            Text("\(entry.wins) win\(entry.wins == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task { await weeklyPickStore.load(for: group) }
        .sheet(isPresented: $showSubmitSheet) {
            if let round = weeklyPickStore.currentRound {
                SubmitSongView(round: round)
            }
        }
    }
}

private struct WinnerRow: View {
    let summary: SubmissionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("This Week's Winner", systemImage: "trophy.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            SongRow(item: summary.submission.item) {
                StaticStarsView(rating: summary.average)
            }
            Text("Submitted by \(summary.submission.submittedByName) · \(summary.ratings.count) rating\(summary.ratings.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct SubmissionRow: View {
    let summary: SubmissionSummary
    @EnvironmentObject var weeklyPickStore: WeeklyPickStore
    @EnvironmentObject var account: AccountStore
    @State private var myStars = 0
    @State private var isSubmitting = false

    private var isMine: Bool { summary.submission.submittedByUserID == account.userID }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SongRow(item: summary.submission.item) {
                StaticStarsView(rating: summary.average)
            }
            Text("Submitted by \(summary.submission.submittedByName) · \(summary.ratings.count) rating\(summary.ratings.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isMine {
                Text("You can't rate your own submission.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    StarRatingView(rating: $myStars, size: 20)
                    if isSubmitting { ProgressView() }
                }
                .onChange(of: myStars) { newValue in
                    guard newValue > 0, !isSubmitting else { return }
                    Task {
                        isSubmitting = true
                        try? await weeklyPickStore.rateSubmission(summary.submission, stars: newValue)
                        isSubmitting = false
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if let mine = summary.ratings.first(where: { $0.raterUserID == account.userID }) {
                myStars = mine.stars
            }
        }
    }
}

struct SubmitSongView: View {
    let round: WeeklyRound
    @EnvironmentObject var weeklyPickStore: WeeklyPickStore
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable { case search = "Search", pasteLink = "Paste Link" }
    @State private var mode: Mode = .search

    // Search mode
    @State private var query = ""
    @State private var searchType: SpotifyItemKind = .track
    @State private var results: [SpotifyItem] = []
    @State private var isSearching = false
    @State private var searchError: String?

    // Paste Link mode
    @State private var linkText = ""
    @State private var linkedItem: SpotifyItem?
    @State private var isLookingUp = false
    @State private var lookupError: String?

    // Shared submit state
    @State private var isSubmitting = false
    @State private var submitError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if let submitError {
                    Text(submitError).foregroundStyle(.red).font(.footnote).padding(.horizontal)
                }

                if isSubmitting {
                    ProgressView("Submitting…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if mode == .search {
                    searchBody
                } else {
                    pasteLinkBody
                }
            }
            .navigationTitle("Submit a Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Search mode

    private var searchBody: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: $searchType) {
                Text("Songs").tag(SpotifyItemKind.track)
                Text("Albums").tag(SpotifyItemKind.album)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if isSearching && results.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let searchError {
                ContentUnavailableFallback(title: "Search failed", message: searchError, systemImage: "exclamationmark.triangle")
            } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && results.isEmpty {
                ContentUnavailableFallback(title: "No results", message: "Try Paste Link instead if you can't find it.", systemImage: "magnifyingglass")
            } else {
                List(results) { item in
                    Button {
                        Task { await submit(item) }
                    } label: {
                        SongRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $query, prompt: "Songs or albums…")
        .task(id: "\(query)|\(searchType.rawValue)") {
            await debouncedSearch()
        }
    }

    private func debouncedSearch() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            return
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled else { return }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            results = try await AppleMusicSearchService.search(query: query, type: searchType)
        } catch {
            searchError = error.localizedDescription
            results = []
        }
    }

    // MARK: - Paste Link mode

    private var pasteLinkBody: some View {
        Form {
            Section {
                HStack {
                    TextField("Paste a Spotify share link…", text: $linkText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if isLookingUp {
                        ProgressView()
                    } else if linkedItem != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                if let lookupError {
                    Text(lookupError).foregroundStyle(.red).font(.footnote)
                }
            } header: {
                Text("Spotify Link")
            } footer: {
                Text("Looked up automatically as soon as you paste a full link.")
            }

            if let linkedItem {
                Section("Song") {
                    SongRow(item: linkedItem)
                    Button("Submit This Song") {
                        Task { await submit(linkedItem) }
                    }
                }
            }
        }
        .task(id: linkText) {
            await autoLookUp()
        }
    }

    private func autoLookUp() async {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            linkedItem = nil
            lookupError = nil
            return
        }
        guard let link = SpotifyLinkParser.firstLink(in: linkText) else {
            linkedItem = nil
            return
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }

        lookupError = nil
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            linkedItem = try await SpotifyMetadataService.lookup(link)
        } catch {
            lookupError = error.localizedDescription
        }
    }

    // MARK: - Submit

    private func submit(_ item: SpotifyItem) async {
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            try await weeklyPickStore.submitSong(item, to: round)
            dismiss()
        } catch {
            submitError = error.localizedDescription
        }
    }
}
