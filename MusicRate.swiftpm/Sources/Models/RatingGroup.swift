import Foundation

struct RatingGroup: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var inviteCode: String
    let ownerUserID: String
    let createdAt: Date
}

struct GroupMember: Identifiable, Hashable {
    var id: String { userID }
    let userID: String
    let displayName: String
    let joinedAt: Date
}
