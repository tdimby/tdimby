import Foundation

/// One week's "song of the week" cycle for a group: members submit songs,
/// everyone but the submitter rates each one, and whichever has the
/// highest average when the round closes wins.
struct WeeklyRound: Identifiable, Hashable {
    let id: String
    let groupID: String
    let weekStartDate: Date
    var isResolved: Bool
    var winningSubmissionID: String?

    var isStale: Bool {
        !isResolved && Date() >= weekStartDate.addingTimeInterval(7 * 24 * 3600)
    }
}

/// A song someone submitted to a round. The song's own details are stored
/// directly on the submission (denormalized) rather than requiring a
/// separate lookup, same reasoning as `Rating.userName`.
struct Submission: Identifiable, Hashable {
    let id: String
    let roundID: String
    let groupID: String
    let item: SpotifyItem
    let submittedByUserID: String
    let submittedByName: String
    let createdAt: Date
}

struct SubmissionRating: Identifiable, Hashable {
    let id: String
    let submissionID: String
    let raterUserID: String
    let raterName: String
    var stars: Int
    let createdAt: Date
}

struct SubmissionSummary: Identifiable, Hashable {
    var id: String { submission.id }
    let submission: Submission
    let ratings: [SubmissionRating]

    var average: Double {
        ratings.isEmpty ? 0 : Double(ratings.map(\.stars).reduce(0, +)) / Double(ratings.count)
    }
}

struct LeaderboardEntry: Identifiable, Hashable {
    var id: String { userID }
    let userID: String
    let name: String
    let wins: Int
}

/// One resolved round's winning song, kept around for the "Past Winners"
/// history - unlike `LeaderboardEntry`, which only survives as a tally.
struct PastWinner: Identifiable, Hashable {
    var id: String { roundID }
    let roundID: String
    let weekStartDate: Date
    let submission: Submission
    let average: Double
    let ratingCount: Int
}
