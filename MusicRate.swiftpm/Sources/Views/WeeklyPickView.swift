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

    @State private var linkText = ""
    @State private var item: SpotifyItem?
    @State private var isLookingUp = false
    @State private var errorText: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Spotify Link") {
                    TextField("Paste a Spotify share link…", text: $linkText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await lookUp() }
                    } label: {
                        if isLookingUp {
                            ProgressView()
                        } else {
                            Text("Look Up")
                        }
                    }
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLookingUp)
                }

                if let item {
                    Section("Song") {
                        SongRow(item: item)
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Submit a Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit")
                        }
                    }
                    .disabled(item == nil || isSubmitting)
                }
            }
        }
    }

    private func lookUp() async {
        errorText = nil
        item = nil
        guard let link = SpotifyLinkParser.firstLink(in: linkText) else {
            errorText = "That doesn't look like a Spotify link."
            return
        }
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            item = try await SpotifyMetadataService.lookup(link)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func submit() async {
        guard let item else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await weeklyPickStore.submitSong(item, to: round)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
