import Foundation

/// Sentinel `groupID` value for a rating not scoped to any group.
let privateAudienceID = "private"

/// Who can see a rating: just you (the default), or one specific group.
enum RatingAudience: Hashable {
    case privateOnly
    case group(RatingGroup)

    var groupIDValue: String {
        switch self {
        case .privateOnly: return privateAudienceID
        case .group(let g): return g.id
        }
    }

    var displayName: String {
        switch self {
        case .privateOnly: return "Private (Just Me)"
        case .group(let g): return g.name
        }
    }
}

struct Rating: Identifiable, Codable, Hashable {
    let id: String
    let songID: String
    let userID: String
    var userName: String
    var stars: Int
    var note: String?
    let groupID: String
    let createdAt: Date

    var isPrivate: Bool { groupID == privateAudienceID }
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
