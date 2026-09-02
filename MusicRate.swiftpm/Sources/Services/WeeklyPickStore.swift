import Foundation

enum WeeklyPickError: LocalizedError {
    case cantRateOwnSubmission
    case noOpenRound

    var errorDescription: String? {
        switch self {
        case .cantRateOwnSubmission:
            return "You can't rate your own submission."
        case .noOpenRound:
            return "There's no open round to submit to — start one first."
        }
    }
}

/// Drives one group's weekly "song of the week" round: submissions,
/// per-submission ratings (excluding the submitter's own), resolving a
/// winner, and a simple wins-based leaderboard. A round auto-resolves once
/// 7 days have passed since it started, checked whenever a member opens
/// the group (no server/cron involved — see the README).
@MainActor
final class WeeklyPickStore: ObservableObject {
    private let account: AccountStore

    @Published var currentRound: WeeklyRound?
    @Published var submissionSummaries: [SubmissionSummary] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var lastError: String?
    @Published private(set) var isLoading = false

    init(account: AccountStore) {
        self.account = account
    }

    func load(for group: RatingGroup) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let token = try await account.validIDToken()
            let roundDocs = try await FirestoreService.query(
                collectionPath: "weeklyRounds",
                equals: ["groupID": group.id],
                orderBy: "weekStartDate",
                descending: true,
                limit: 1,
                idToken: token
            )
            if let doc = roundDocs.first, var round = round(from: doc) {
                if round.isStale {
                    round = try await resolve(round, token: token)
                }
                currentRound = round
                await loadSubmissionSummaries(roundID: round.id, groupID: round.groupID, token: token)
            } else {
                currentRound = nil
                submissionSummaries = []
            }
            await loadLeaderboard(group: group, token: token)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func startNewRound(for group: RatingGroup) async throws {
        let token = try await account.validIDToken()
        let roundID = UUID().uuidString
        _ = try await FirestoreService.setDocument(
            path: "weeklyRounds/\(roundID)",
            fields: ["groupID": group.id, "weekStartDate": Date(), "isResolved": false, "winningSubmissionID": nil],
            idToken: token
        )
        await load(for: group)
    }

    func submitSong(_ item: SpotifyItem, to round: WeeklyRound) async throws {
        guard let userID = account.userID else { throw MusicStoreError.notSignedIn }
        let token = try await account.validIDToken()
        let submissionID = "\(round.id)_\(userID)_\(item.spotifyID)"
        _ = try await FirestoreService.setDocument(
            path: "submissions/\(submissionID)",
            fields: [
                "roundID": round.id,
                "groupID": round.groupID,
                "songID": item.spotifyID,
                "songKind": item.kind.rawValue,
                "songTitle": item.title,
                "songSubtitle": item.subtitle,
                "songArtworkURL": item.artworkURL?.absoluteString,
                "songSpotifyURL": item.spotifyURL.absoluteString,
                "songSource": item.source.rawValue,
                "submittedByUserID": userID,
                "submittedByName": account.displayName,
                "createdAt": Date()
            ],
            idToken: token
        )
        await loadSubmissionSummaries(roundID: round.id, groupID: round.groupID, token: token)
    }

    func rateSubmission(_ submission: Submission, stars: Int) async throws {
        guard let userID = account.userID else { throw MusicStoreError.notSignedIn }
        guard submission.submittedByUserID != userID else { throw WeeklyPickError.cantRateOwnSubmission }
        let token = try await account.validIDToken()
        let ratingID = "\(submission.id)_\(userID)"
        _ = try await FirestoreService.setDocument(
            path: "submissionRatings/\(ratingID)",
            fields: [
                "submissionID": submission.id,
                "raterUserID": userID,
                "raterName": account.displayName,
                "stars": stars,
                "createdAt": Date()
            ],
            idToken: token
        )
        await loadSubmissionSummaries(roundID: submission.roundID, groupID: submission.groupID, token: token)
    }

    func closeRound(_ round: WeeklyRound) async throws {
        let token = try await account.validIDToken()
        currentRound = try await resolve(round, token: token)
    }

    // MARK: - Loading

    private func loadSubmissionSummaries(roundID: String, groupID: String, token: String) async {
        guard let docs = try? await FirestoreService.query(collectionPath: "submissions", equals: ["roundID": roundID, "groupID": groupID], idToken: token) else {
            submissionSummaries = []
            return
        }
        let subs = docs.compactMap(submission(from:)).sorted { $0.createdAt < $1.createdAt }
        var summaries: [SubmissionSummary] = []
        for sub in subs {
            let ratingDocs = (try? await FirestoreService.query(collectionPath: "submissionRatings", equals: ["submissionID": sub.id], idToken: token)) ?? []
            let ratings = ratingDocs.compactMap(submissionRating(from:))
            summaries.append(SubmissionSummary(submission: sub, ratings: ratings))
        }
        submissionSummaries = summaries
    }

    private func loadLeaderboard(group: RatingGroup, token: String) async {
        guard let roundDocs = try? await FirestoreService.query(
            collectionPath: "weeklyRounds",
            equals: ["groupID": group.id, "isResolved": true],
            idToken: token
        ) else {
            leaderboard = []
            return
        }
        var tally: [String: (name: String, wins: Int)] = [:]
        for doc in roundDocs {
            guard
                let winningID = doc.fields["winningSubmissionID"] as? String,
                let subDoc = try? await FirestoreService.getDocument(path: "submissions/\(winningID)", idToken: token),
                let sub = submission(from: subDoc)
            else { continue }
            let current = tally[sub.submittedByUserID] ?? (name: sub.submittedByName, wins: 0)
            tally[sub.submittedByUserID] = (name: current.name, wins: current.wins + 1)
        }
        leaderboard = tally
            .map { LeaderboardEntry(userID: $0.key, name: $0.value.name, wins: $0.value.wins) }
            .sorted { $0.wins > $1.wins }
    }

    /// Picks the highest-average submission (ties broken by most ratings,
    /// then earliest submitted) and marks the round resolved. A round with
    /// no rated submissions resolves with no winner.
    private func resolve(_ round: WeeklyRound, token: String) async throws -> WeeklyRound {
        let subDocs = try await FirestoreService.query(collectionPath: "submissions", equals: ["roundID": round.id, "groupID": round.groupID], idToken: token)
        let subs = subDocs.compactMap(submission(from:)).sorted { $0.createdAt < $1.createdAt }

        var winnerID: String?
        var bestAverage = -1.0
        var bestCount = -1
        for sub in subs {
            let ratingDocs = (try? await FirestoreService.query(collectionPath: "submissionRatings", equals: ["submissionID": sub.id], idToken: token)) ?? []
            let ratings = ratingDocs.compactMap(submissionRating(from:))
            guard !ratings.isEmpty else { continue }
            let average = Double(ratings.map(\.stars).reduce(0, +)) / Double(ratings.count)
            if average > bestAverage || (average == bestAverage && ratings.count > bestCount) {
                bestAverage = average
                bestCount = ratings.count
                winnerID = sub.id
            }
        }

        let doc = try await FirestoreService.setDocument(
            path: "weeklyRounds/\(round.id)",
            fields: ["groupID": round.groupID, "weekStartDate": round.weekStartDate, "isResolved": true, "winningSubmissionID": winnerID],
            idToken: token
        )
        return self.round(from: doc) ?? round
    }

    // MARK: - Firestore <-> model mapping

    private func round(from doc: FirestoreDocument) -> WeeklyRound? {
        let fields = doc.fields
        guard
            let groupID = fields["groupID"] as? String,
            let weekStartDate = fields["weekStartDate"] as? Date,
            let isResolved = fields["isResolved"] as? Bool
        else { return nil }
        return WeeklyRound(
            id: doc.id,
            groupID: groupID,
            weekStartDate: weekStartDate,
            isResolved: isResolved,
            winningSubmissionID: fields["winningSubmissionID"] as? String
        )
    }

    private func submission(from doc: FirestoreDocument) -> Submission? {
        let fields = doc.fields
        guard
            let roundID = fields["roundID"] as? String,
            let groupID = fields["groupID"] as? String,
            let songID = fields["songID"] as? String,
            let kindRaw = fields["songKind"] as? String,
            let kind = SpotifyItemKind(rawValue: kindRaw),
            let title = fields["songTitle"] as? String,
            let urlString = fields["songSpotifyURL"] as? String,
            let url = URL(string: urlString),
            let submittedByUserID = fields["submittedByUserID"] as? String,
            let submittedByName = fields["submittedByName"] as? String,
            let createdAt = fields["createdAt"] as? Date
        else { return nil }
        let source = (fields["songSource"] as? String).flatMap(MusicSource.init(rawValue:)) ?? .spotify
        let artworkURL = (fields["songArtworkURL"] as? String).flatMap(URL.init(string:))
        let item = SpotifyItem(
            spotifyID: songID,
            kind: kind,
            title: title,
            subtitle: fields["songSubtitle"] as? String ?? kind.displayName,
            artworkURL: artworkURL,
            spotifyURL: url,
            source: source
        )
        return Submission(id: doc.id, roundID: roundID, groupID: groupID, item: item, submittedByUserID: submittedByUserID, submittedByName: submittedByName, createdAt: createdAt)
    }

    private func submissionRating(from doc: FirestoreDocument) -> SubmissionRating? {
        let fields = doc.fields
        guard
            let submissionID = fields["submissionID"] as? String,
            let raterUserID = fields["raterUserID"] as? String,
            let raterName = fields["raterName"] as? String,
            let stars = fields["stars"] as? Int,
            let createdAt = fields["createdAt"] as? Date
        else { return nil }
        return SubmissionRating(id: doc.id, submissionID: submissionID, raterUserID: raterUserID, raterName: raterName, stars: stars, createdAt: createdAt)
    }
}
