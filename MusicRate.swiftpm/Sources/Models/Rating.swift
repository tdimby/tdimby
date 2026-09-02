import Foundation

/// The sentinel `groupID` used for a rating shared with everyone rather than one group.
let worldwideGroupID = "worldwide"

struct Rating: Identifiable, Codable, Hashable {
    let id: String
    let songID: String
    let userID: String
    var userName: String
    var stars: Int
    var note: String?
    let groupID: String
    let createdAt: Date

    var isWorldwide: Bool { groupID == worldwideGroupID }
}

struct FeedItem: Identifiable, Hashable {
    var id: String { rating.id }
    let rating: Rating
    let item: SpotifyItem
}

struct RatingSummary {
    let average: Double
    let count: Int

    static let empty = RatingSummary(average: 0, count: 0)

    init(average: Double, count: Int) {
        self.average = average
        self.count = count
    }

    init(ratings: [Rating]) {
        count = ratings.count
        average = ratings.isEmpty ? 0 : Double(ratings.map(\.stars).reduce(0, +)) / Double(ratings.count)
    }
}
