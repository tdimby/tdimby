import Foundation
import CloudKit

struct RatingGroup: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var inviteCode: String
    let ownerUserID: String
    let createdAt: Date

    init?(record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let inviteCode = record["inviteCode"] as? String,
            let ownerUserID = record["ownerUserID"] as? String,
            let createdAt = record["createdAt"] as? Date
        else { return nil }

        self.id = record.recordID.recordName
        self.name = name
        self.inviteCode = inviteCode
        self.ownerUserID = ownerUserID
        self.createdAt = createdAt
    }
}
