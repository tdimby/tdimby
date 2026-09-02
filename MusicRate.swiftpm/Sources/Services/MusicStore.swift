import Foundation
import CloudKit

enum MusicStoreError: LocalizedError {
    case notSignedIn
    case invalidGroupName
    case invalidInviteCode
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to iCloud in Settings to rate music and join groups."
        case .invalidGroupName:
            return "Give your group a name."
        case .invalidInviteCode:
            return "That invite code doesn't match any group."
        case .decodingFailed:
            return "Something went wrong saving that to CloudKit."
        }
    }
}

/// Backs the app with CloudKit's public database. `groupID` is
/// `worldwideGroupID` for ratings visible to everyone, or a group's record
/// name for ratings scoped to that group only.
@MainActor
final class MusicStore: ObservableObject {
    private static let songType = "Song"
    private static let ratingType = "Rating"
    private static let groupType = "RatingGroup"
    private static let membershipType = "GroupMembership"

    private let container = CKContainer.default()
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private var songCache: [String: SpotifyItem] = [:]

    @Published private(set) var currentUserID: String?
    @Published private(set) var isSignedInToiCloud = false
    @Published var myGroups: [RatingGroup] = []
    @Published var worldwideFeed: [FeedItem] = []
    @Published var myRatings: [Rating] = []
    @Published var lastError: String?
    @Published private(set) var isLoading = false

    func start() async {
        await loadCurrentUser()
        guard currentUserID != nil else { return }
        await refreshMyGroups()
        await refreshWorldwideFeed()
        await refreshMyRatings()
    }

    private func loadCurrentUser() async {
        do {
            let recordID = try await container.userRecordID()
            currentUserID = recordID.recordName
            isSignedInToiCloud = true
        } catch {
            isSignedInToiCloud = false
            lastError = "Sign in to iCloud in Settings to rate music and sync with others."
        }
    }

    // MARK: - Songs

    @discardableResult
    func upsertSong(_ item: SpotifyItem) async throws -> SpotifyItem {
        let recordID = CKRecord.ID(recordName: item.spotifyID)
        let record = (try? await publicDB.record(for: recordID)) ?? CKRecord(recordType: Self.songType, recordID: recordID)
        record["spotifyID"] = item.spotifyID
        record["kind"] = item.kind.rawValue
        record["title"] = item.title
        record["subtitle"] = item.subtitle
        record["artworkURL"] = item.artworkURL?.absoluteString
        record["spotifyURL"] = item.spotifyURL.absoluteString
        _ = try await publicDB.save(record)
        songCache[item.spotifyID] = item
        return item
    }

    private func fetchSongs(ids: some Sequence<String>) async {
        let missing = Set(ids).subtracting(songCache.keys)
        guard !missing.isEmpty else { return }
        let recordIDs = missing.map { CKRecord.ID(recordName: $0) }
        guard let fetched = try? await publicDB.records(for: recordIDs) else { return }
        for result in fetched.values {
            if case .success(let record) = result, let item = SpotifyItem(record: record) {
                songCache[item.spotifyID] = item
            }
        }
    }

    // MARK: - Ratings

    @discardableResult
    func submitRating(for item: SpotifyItem, stars: Int, note: String?, group: RatingGroup?, displayName: String) async throws -> Rating {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        try await upsertSong(item)

        let groupID = group?.id ?? worldwideGroupID
        let recordID = CKRecord.ID(recordName: "rating_\(userID)_\(item.spotifyID)_\(groupID)")
        let record: CKRecord
        if let existing = try? await publicDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: Self.ratingType, recordID: recordID)
            record["createdAt"] = Date()
        }
        record["songID"] = item.spotifyID
        record["userID"] = userID
        record["userName"] = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Anonymous" : displayName
        record["stars"] = stars
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        record["note"] = (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote
        record["groupID"] = groupID

        let saved = try await publicDB.save(record)
        guard let rating = Rating(record: saved) else { throw MusicStoreError.decodingFailed }

        await refreshWorldwideFeed()
        await refreshMyRatings()
        return rating
    }

    func ratings(forSongID songID: String, groupID: String) async throws -> [Rating] {
        let predicate = NSPredicate(format: "songID == %@ AND groupID == %@", songID, groupID)
        let query = CKQuery(recordType: Self.ratingType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let result = try await publicDB.records(matching: query)
        return result.matchResults.compactMap { try? $0.1.get() }.compactMap(Rating.init(record:))
    }

    func summary(forSongID songID: String, groupID: String) async throws -> RatingSummary {
        RatingSummary(ratings: try await ratings(forSongID: songID, groupID: groupID))
    }

    func feed(for group: RatingGroup?, limit: Int = 50) async throws -> [FeedItem] {
        let groupID = group?.id ?? worldwideGroupID
        let predicate = NSPredicate(format: "groupID == %@", groupID)
        let query = CKQuery(recordType: Self.ratingType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let result = try await publicDB.records(matching: query, resultsLimit: limit)
        let ratings = result.matchResults.compactMap { try? $0.1.get() }.compactMap(Rating.init(record:))
        await fetchSongs(ids: ratings.map(\.songID))
        return ratings.compactMap { rating in
            songCache[rating.songID].map { FeedItem(rating: rating, item: $0) }
        }
    }

    func refreshWorldwideFeed() async {
        isLoading = true
        defer { isLoading = false }
        do {
            worldwideFeed = try await feed(for: nil)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func myFeedItems() async -> [FeedItem] {
        await fetchSongs(ids: myRatings.map(\.songID))
        return myRatings.compactMap { rating in
            songCache[rating.songID].map { FeedItem(rating: rating, item: $0) }
        }
    }

    func refreshMyRatings() async {
        guard let userID = currentUserID else { return }
        do {
            let predicate = NSPredicate(format: "userID == %@", userID)
            let query = CKQuery(recordType: Self.ratingType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            let result = try await publicDB.records(matching: query, resultsLimit: 100)
            myRatings = result.matchResults.compactMap { try? $0.1.get() }.compactMap(Rating.init(record:))
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Groups

    func refreshMyGroups() async {
        guard let userID = currentUserID else { return }
        do {
            let predicate = NSPredicate(format: "userID == %@", userID)
            let query = CKQuery(recordType: Self.membershipType, predicate: predicate)
            let result = try await publicDB.records(matching: query)
            let memberships = result.matchResults.compactMap { try? $0.1.get() }
            let groupIDs = memberships.compactMap { $0["groupID"] as? String }
            guard !groupIDs.isEmpty else {
                myGroups = []
                return
            }
            let recordIDs = groupIDs.map { CKRecord.ID(recordName: $0) }
            let fetched = try await publicDB.records(for: recordIDs)
            myGroups = fetched.values.compactMap { result -> RatingGroup? in
                guard case .success(let record) = result else { return nil }
                return RatingGroup(record: record)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createGroup(name: String) async throws -> RatingGroup {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MusicStoreError.invalidGroupName }

        let record = CKRecord(recordType: Self.groupType)
        record["name"] = trimmed
        record["inviteCode"] = Self.randomInviteCode()
        record["ownerUserID"] = userID
        record["createdAt"] = Date()
        let saved = try await publicDB.save(record)
        guard let group = RatingGroup(record: saved) else { throw MusicStoreError.decodingFailed }

        try await join(group: group, userID: userID)
        await refreshMyGroups()
        return group
    }

    func joinGroup(inviteCode: String) async throws -> RatingGroup {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { throw MusicStoreError.invalidInviteCode }

        let predicate = NSPredicate(format: "inviteCode == %@", code)
        let query = CKQuery(recordType: Self.groupType, predicate: predicate)
        let result = try await publicDB.records(matching: query, resultsLimit: 1)
        guard
            let first = result.matchResults.first,
            let record = try? first.1.get(),
            let group = RatingGroup(record: record)
        else { throw MusicStoreError.invalidInviteCode }

        try await join(group: group, userID: userID)
        await refreshMyGroups()
        return group
    }

    private func join(group: RatingGroup, userID: String) async throws {
        let recordID = CKRecord.ID(recordName: "member_\(group.id)_\(userID)")
        let record = CKRecord(recordType: Self.membershipType, recordID: recordID)
        record["groupID"] = group.id
        record["userID"] = userID
        record["joinedAt"] = Date()
        _ = try await publicDB.save(record)
    }

    private static func randomInviteCode(length: Int = 6) -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }
}
