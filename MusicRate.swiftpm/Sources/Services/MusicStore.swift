import Foundation

enum MusicStoreError: LocalizedError {
    case invalidGroupName
    case invalidInviteCode

    var errorDescription: String? {
        switch self {
        case .invalidGroupName:
            return "Give your group a name."
        case .invalidInviteCode:
            return "That invite code doesn't match any group."
        }
    }
}

private struct Membership: Codable {
    let groupID: String
    let userID: String
    let joinedAt: Date
}

private struct LocalDatabase: Codable {
    var songs: [String: SpotifyItem] = [:]
    var ratings: [String: Rating] = [:]
    var groups: [String: RatingGroup] = [:]
    var memberships: [Membership] = []
}

/// Stores everything as a JSON file in the app's Documents folder — no
/// server, no account, no special entitlement required. That also means
/// "worldwide" only means "everyone who's rated something on this device":
/// there's no shared backend behind it. Swap this out for CloudKit or a
/// real API once you're building this in Xcode rather than Swift
/// Playgrounds — see the README for why it isn't wired up that way already.
@MainActor
final class MusicStore: ObservableObject {
    private let fileURL: URL
    private var db: LocalDatabase

    let currentUserID: String
    @Published var myGroups: [RatingGroup] = []
    @Published var worldwideFeed: [FeedItem] = []
    @Published var myRatings: [Rating] = []
    @Published var lastError: String?

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("musicrate.json")
        currentUserID = Self.loadOrCreateUserID()
        db = Self.loadDatabase(from: fileURL)
        refreshAll()
    }

    func start() async {
        refreshAll()
    }

    // MARK: - Songs

    @discardableResult
    func upsertSong(_ item: SpotifyItem) async throws -> SpotifyItem {
        db.songs[item.spotifyID] = item
        save()
        return item
    }

    // MARK: - Ratings

    @discardableResult
    func submitRating(for item: SpotifyItem, stars: Int, note: String?, group: RatingGroup?, displayName: String) async throws -> Rating {
        try await upsertSong(item)

        let groupID = group?.id ?? worldwideGroupID
        let id = "\(currentUserID)_\(item.spotifyID)_\(groupID)"
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rating = Rating(
            id: id,
            songID: item.spotifyID,
            userID: currentUserID,
            userName: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Anonymous" : displayName,
            stars: stars,
            note: (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote,
            groupID: groupID,
            createdAt: db.ratings[id]?.createdAt ?? Date()
        )
        db.ratings[id] = rating
        save()
        refreshWorldwideFeedNow()
        refreshMyRatingsNow()
        return rating
    }

    func ratings(forSongID songID: String, groupID: String) async throws -> [Rating] {
        db.ratings.values
            .filter { $0.songID == songID && $0.groupID == groupID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func summary(forSongID songID: String, groupID: String) async throws -> RatingSummary {
        RatingSummary(ratings: try await ratings(forSongID: songID, groupID: groupID))
    }

    func feed(for group: RatingGroup?, limit: Int = 50) async throws -> [FeedItem] {
        feedItems(groupID: group?.id ?? worldwideGroupID, limit: limit)
    }

    func refreshWorldwideFeed() async {
        refreshWorldwideFeedNow()
    }

    func myFeedItems() async -> [FeedItem] {
        myRatings.compactMap { rating in
            db.songs[rating.songID].map { FeedItem(rating: rating, item: $0) }
        }
    }

    func refreshMyRatings() async {
        refreshMyRatingsNow()
    }

    // MARK: - Groups

    func refreshMyGroups() async {
        refreshMyGroupsNow()
    }

    func createGroup(name: String) async throws -> RatingGroup {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MusicStoreError.invalidGroupName }

        let group = RatingGroup(
            id: UUID().uuidString,
            name: trimmed,
            inviteCode: Self.randomInviteCode(),
            ownerUserID: currentUserID,
            createdAt: Date()
        )
        db.groups[group.id] = group
        join(group: group)
        save()
        refreshMyGroupsNow()
        return group
    }

    func joinGroup(inviteCode: String) async throws -> RatingGroup {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let group = db.groups.values.first(where: { $0.inviteCode == code }) else {
            throw MusicStoreError.invalidInviteCode
        }
        join(group: group)
        save()
        refreshMyGroupsNow()
        return group
    }

    private func join(group: RatingGroup) {
        guard !db.memberships.contains(where: { $0.groupID == group.id && $0.userID == currentUserID }) else { return }
        db.memberships.append(Membership(groupID: group.id, userID: currentUserID, joinedAt: Date()))
    }

    // MARK: - Derived state

    private func refreshAll() {
        refreshMyGroupsNow()
        refreshWorldwideFeedNow()
        refreshMyRatingsNow()
    }

    private func refreshMyGroupsNow() {
        let groupIDs = Set(db.memberships.filter { $0.userID == currentUserID }.map(\.groupID))
        myGroups = db.groups.values
            .filter { groupIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func refreshWorldwideFeedNow() {
        worldwideFeed = feedItems(groupID: worldwideGroupID, limit: 50)
    }

    private func refreshMyRatingsNow() {
        myRatings = db.ratings.values
            .filter { $0.userID == currentUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func feedItems(groupID: String, limit: Int) -> [FeedItem] {
        db.ratings.values
            .filter { $0.groupID == groupID }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .compactMap { rating in db.songs[rating.songID].map { FeedItem(rating: rating, item: $0) } }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(db) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func loadDatabase(from url: URL) -> LocalDatabase {
        guard
            let data = try? Data(contentsOf: url),
            let db = try? JSONDecoder().decode(LocalDatabase.self, from: data)
        else { return LocalDatabase() }
        return db
    }

    private static func loadOrCreateUserID() -> String {
        let key = "musicrate.userID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    private static func randomInviteCode(length: Int = 6) -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }
}
