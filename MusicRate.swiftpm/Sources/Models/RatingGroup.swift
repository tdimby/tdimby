import Foundation

struct RatingGroup: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var inviteCode: String
    let ownerUserID: String
    let createdAt: Date
}
