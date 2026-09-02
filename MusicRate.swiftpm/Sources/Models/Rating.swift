import Foundation
import CloudKit

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

    init?(record: CKRecord) {
        guard
            let songID = record["songID"] as? String,
            let userID = record["userID"] as? String,
            let userName = record["userName"] as? String,
            let stars = record["stars"] as? Int,
            let groupID = record["groupID"] as? String,
            let createdAt = record["createdAt"] as? Date
        else { return nil }

        self.id = record.recordID.recordName
        self.songID = songID
        self.userID = userID
        self.userName = userName
        self.stars = stars
        self.note = record["note"] as? String
        self.groupID = groupID
        self.createdAt = createdAt
    }
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
