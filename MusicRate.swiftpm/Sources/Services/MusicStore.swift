import Foundation

enum MusicStoreError: LocalizedError {
    case notSignedIn
    case invalidGroupName
    case invalidInviteCode
    case notGroupOwner

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in first."
        case .invalidGroupName:
            return "Give your group a name."
        case .invalidInviteCode:
            return "That invite code doesn't match any group."
        case .notGroupOwner:
            return "Only the group's owner can do that."
        }
    }
}

/// Backs the app with Firestore. `groupID` on a rating is either
/// `privateAudienceID` (visible only to its author) or a group's document
/// ID (visible to that group's members) - see `RatingAudience`.
@MainActor
final class MusicStore: ObservableObject {
    private let account: AccountStore
    private var songCache: [String: SpotifyItem] = [:]

    @Published var myGroups: [RatingGroup] = []
    @Published var groupMemberCounts: [String: Int] = [:]
    @Published var myRatings: [Rating] = []
    @Published var lastError: String?

    init(account: AccountStore) {
        self.account = account
    }

    private var currentUserID: String? { account.userID }

    func start() async {
        guard account.isSignedIn else { return }
        await refreshMyGroups()
        await refreshMyRatings()
    }

    // MARK: - Songs

    @discardableResult
    func upsertSong(_ item: SpotifyItem) async throws -> SpotifyItem {
        let token = try await account.validIDToken()
        try await FirestoreService.setDocument(path: "songs/\(item.spotifyID)", fields: songFields(item), idToken: token)
        songCache[item.spotifyID] = item
        return item
    }

    private func fetchSongs(ids: some Sequence<String>) async {
        let token = try? await account.validIDToken()
        guard let token else { return }
        let missing = Set(ids).subtracting(songCache.keys)
        for id in missing {
            if let doc = try? await FirestoreService.getDocument(path: "songs/\(id)", idToken: token),
               let item = song(from: doc) {
                songCache[item.spotifyID] = item
            }
        }
    }

    // MARK: - Ratings

    @discardableResult
    func submitRating(for item: SpotifyItem, stars: Int, note: String?, audience: RatingAudience, displayName: String) async throws -> Rating {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        try await upsertSong(item)
        let token = try await account.validIDToken()

        let groupID = audience.groupIDValue
        let ratingID = "\(userID)_\(item.spotifyID)_\(groupID)"
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = try? await FirestoreService.getDocument(path: "ratings/\(ratingID)", idToken: token)
        let createdAt = (existing?.fields["createdAt"] as? Date) ?? Date()

        let doc = try await FirestoreService.setDocument(
            path: "ratings/\(ratingID)",
            fields: [
                "songID": item.spotifyID,
                "userID": userID,
                "userName": displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Anonymous" : displayName,
                "stars": stars,
                "note": (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote,
                "groupID": groupID,
                "createdAt": createdAt
            ],
            idToken: token
        )
        guard let rating = rating(from: doc) else { throw FirestoreError.decodingFailed }

        await refreshMyRatings()
        return rating
    }

    func ratings(forSongID songID: String, groupID: String) async throws -> [Rating] {
        let token = try await account.validIDToken()
        let docs = try await FirestoreService.query(
            collectionPath: "ratings",
            equals: ["songID": songID, "groupID": groupID],
            orderBy: "createdAt",
            descending: true,
            idToken: token
        )
        return docs.compactMap(rating(from:))
    }

    func summary(forSongID songID: String, groupID: String) async throws -> RatingSummary {
        RatingSummary(ratings: try await ratings(forSongID: songID, groupID: groupID))
    }

    func feed(for group: RatingGroup, limit: Int = 50) async throws -> [FeedItem] {
        let token = try await account.validIDToken()
        let docs = try await FirestoreService.query(
            collectionPath: "ratings",
            equals: ["groupID": group.id],
            orderBy: "createdAt",
            descending: true,
            limit: limit,
            idToken: token
        )
        let ratings = docs.compactMap(rating(from:))
        await fetchSongs(ids: ratings.map(\.songID))
        return ratings.compactMap { rating in
            songCache[rating.songID].map { FeedItem(rating: rating, item: $0) }
        }
    }

    /// Tally of how many ratings each member has posted to this group -
    /// one leg of the points leaderboard (`GroupDetailView`), alongside
    /// weekly-round submissions and wins from `WeeklyPickStore`.
    func ratingCounts(for group: RatingGroup) async -> [String: (name: String, count: Int)] {
        guard let token = try? await account.validIDToken() else { return [:] }
        let docs = (try? await FirestoreService.query(
            collectionPath: "ratings",
            equals: ["groupID": group.id],
            idToken: token
        )) ?? []
        var tally: [String: (name: String, count: Int)] = [:]
        for doc in docs {
            guard let userID = doc.fields["userID"] as? String else { continue }
            let name = doc.fields["userName"] as? String ?? "Member"
            tally[userID] = (name: name, count: (tally[userID]?.count ?? 0) + 1)
        }
        return tally
    }

    /// Every rating ever posted to this group, unlike `feed(for:)` which
    /// caps at the most recent 50 - used for "Song Champions", a genuinely
    /// all-time ranking rather than a recent-activity one.
    func allRatings(for group: RatingGroup) async -> [Rating] {
        guard let token = try? await account.validIDToken() else { return [] }
        let docs = (try? await FirestoreService.query(
            collectionPath: "ratings",
            equals: ["groupID": group.id],
            idToken: token
        )) ?? []
        return docs.compactMap(rating(from:))
    }

    /// Resolves song IDs to their cached `SpotifyItem` details, fetching
    /// any not already cached.
    func songs(forIDs ids: some Sequence<String>) async -> [String: SpotifyItem] {
        await fetchSongs(ids: ids)
        var result: [String: SpotifyItem] = [:]
        for id in ids {
            if let item = songCache[id] { result[id] = item }
        }
        return result
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
            let token = try await account.validIDToken()
            let docs = try await FirestoreService.query(
                collectionPath: "ratings",
                equals: ["userID": userID],
                orderBy: "createdAt",
                descending: true,
                limit: 100,
                idToken: token
            )
            myRatings = docs.compactMap(rating(from:))
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Groups

    func refreshMyGroups() async {
        guard let userID = currentUserID else { return }
        do {
            let token = try await account.validIDToken()
            let memberships = try await FirestoreService.query(
                collectionPath: "memberships",
                equals: ["userID": userID],
                idToken: token
            )
            let groupIDs = memberships.compactMap { $0.fields["groupID"] as? String }
            var groups: [RatingGroup] = []
            var counts: [String: Int] = [:]
            for groupID in groupIDs {
                if let doc = try? await FirestoreService.getDocument(path: "groups/\(groupID)", idToken: token),
                   let group = group(from: doc) {
                    groups.append(group)
                    let memberDocs = (try? await FirestoreService.query(
                        collectionPath: "memberships",
                        equals: ["groupID": groupID],
                        idToken: token
                    )) ?? []
                    counts[groupID] = memberDocs.count
                }
            }
            myGroups = groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            groupMemberCounts = counts
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createGroup(name: String, icon: String = "🎵", description: String? = nil) async throws -> RatingGroup {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MusicStoreError.invalidGroupName }
        let token = try await account.validIDToken()
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)

        let groupID = UUID().uuidString
        let doc = try await FirestoreService.setDocument(
            path: "groups/\(groupID)",
            fields: [
                "name": trimmed,
                "inviteCode": Self.randomInviteCode(),
                "ownerUserID": userID,
                "createdAt": Date(),
                "icon": icon,
                "description": (trimmedDescription?.isEmpty ?? true) ? nil : trimmedDescription
            ],
            idToken: token
        )
        guard let group = group(from: doc) else { throw FirestoreError.decodingFailed }

        try await join(group: group, userID: userID, token: token)
        await refreshMyGroups()
        return group
    }

    /// `PATCH` without an update mask replaces the whole document, so
    /// every field - not just the ones being changed - has to be carried
    /// along on every group write (see `AccountStore.saveProfile` for the
    /// same issue with user profiles).
    @discardableResult
    func updateGroup(_ group: RatingGroup, name: String, icon: String, description: String?) async throws -> RatingGroup {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        guard userID == group.ownerUserID else { throw MusicStoreError.notGroupOwner }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw MusicStoreError.invalidGroupName }
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = try await account.validIDToken()

        let doc = try await FirestoreService.setDocument(
            path: "groups/\(group.id)",
            fields: [
                "name": trimmedName,
                "inviteCode": group.inviteCode,
                "ownerUserID": group.ownerUserID,
                "createdAt": group.createdAt,
                "icon": icon,
                "description": (trimmedDescription?.isEmpty ?? true) ? nil : trimmedDescription
            ],
            idToken: token
        )
        guard let updated = self.group(from: doc) else { throw FirestoreError.decodingFailed }
        if let index = myGroups.firstIndex(where: { $0.id == updated.id }) {
            myGroups[index] = updated
        }
        return updated
    }

    /// Invalidates the old invite code immediately - anyone who hasn't
    /// already joined with it will need the new one.
    @discardableResult
    func regenerateInviteCode(for group: RatingGroup) async throws -> RatingGroup {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        guard userID == group.ownerUserID else { throw MusicStoreError.notGroupOwner }
        let token = try await account.validIDToken()

        let doc = try await FirestoreService.setDocument(
            path: "groups/\(group.id)",
            fields: [
                "name": group.name,
                "inviteCode": Self.randomInviteCode(),
                "ownerUserID": group.ownerUserID,
                "createdAt": group.createdAt,
                "icon": group.icon,
                "description": group.description
            ],
            idToken: token
        )
        guard let updated = self.group(from: doc) else { throw FirestoreError.decodingFailed }
        if let index = myGroups.firstIndex(where: { $0.id == updated.id }) {
            myGroups[index] = updated
        }
        return updated
    }

    func joinGroup(inviteCode: String) async throws -> RatingGroup {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { throw MusicStoreError.invalidInviteCode }
        let token = try await account.validIDToken()

        let matches = try await FirestoreService.query(collectionPath: "groups", equals: ["inviteCode": code], limit: 1, idToken: token)
        guard let doc = matches.first, let group = group(from: doc) else {
            throw MusicStoreError.invalidInviteCode
        }

        try await join(group: group, userID: userID, token: token)
        await refreshMyGroups()
        return group
    }

    private func join(group: RatingGroup, userID: String, token: String) async throws {
        try await FirestoreService.setDocument(
            path: "memberships/\(group.id)_\(userID)",
            fields: ["groupID": group.id, "userID": userID, "joinedAt": Date()],
            idToken: token
        )
    }

    func members(of group: RatingGroup) async throws -> [GroupMember] {
        let token = try await account.validIDToken()
        let membershipDocs = try await FirestoreService.query(
            collectionPath: "memberships",
            equals: ["groupID": group.id],
            idToken: token
        )
        var members: [GroupMember] = []
        for doc in membershipDocs {
            guard let userID = doc.fields["userID"] as? String, let joinedAt = doc.fields["joinedAt"] as? Date else { continue }
            let userDoc = try? await FirestoreService.getDocument(path: "users/\(userID)", idToken: token)
            let name = userDoc?.fields["displayName"] as? String
            members.append(GroupMember(userID: userID, displayName: (name?.isEmpty == false ? name! : "Member"), joinedAt: joinedAt))
        }
        return members.sorted { $0.joinedAt < $1.joinedAt }
    }

    func leaveGroup(_ group: RatingGroup) async throws {
        guard let userID = currentUserID else { throw MusicStoreError.notSignedIn }
        let token = try await account.validIDToken()
        try await FirestoreService.deleteDocument(path: "memberships/\(group.id)_\(userID)", idToken: token)
        await refreshMyGroups()
    }

    // MARK: - Firestore <-> model mapping

    private func songFields(_ item: SpotifyItem) -> [String: Any?] {
        [
            "spotifyID": item.spotifyID,
            "kind": item.kind.rawValue,
            "title": item.title,
            "subtitle": item.subtitle,
            "artworkURL": item.artworkURL?.absoluteString,
            "spotifyURL": item.spotifyURL.absoluteString,
            "source": item.source.rawValue,
            "previewURL": item.previewURL?.absoluteString
        ]
    }

    private func song(from doc: FirestoreDocument) -> SpotifyItem? {
        let fields = doc.fields
        guard
            let spotifyID = fields["spotifyID"] as? String,
            let kindRaw = fields["kind"] as? String,
            let kind = SpotifyItemKind(rawValue: kindRaw),
            let title = fields["title"] as? String,
            let urlString = fields["spotifyURL"] as? String,
            let spotifyURL = URL(string: urlString)
        else { return nil }
        let artworkURL = (fields["artworkURL"] as? String).flatMap(URL.init(string:))
        let source = (fields["source"] as? String).flatMap(MusicSource.init(rawValue:)) ?? .spotify
        let previewURL = (fields["previewURL"] as? String).flatMap(URL.init(string:))
        return SpotifyItem(
            spotifyID: spotifyID,
            kind: kind,
            title: title,
            subtitle: fields["subtitle"] as? String ?? kind.displayName,
            artworkURL: artworkURL,
            spotifyURL: spotifyURL,
            source: source,
            previewURL: previewURL
        )
    }

    private func rating(from doc: FirestoreDocument) -> Rating? {
        let fields = doc.fields
        guard
            let songID = fields["songID"] as? String,
            let userID = fields["userID"] as? String,
            let userName = fields["userName"] as? String,
            let stars = fields["stars"] as? Int,
            let groupID = fields["groupID"] as? String,
            let createdAt = fields["createdAt"] as? Date
        else { return nil }
        return Rating(
            id: doc.id,
            songID: songID,
            userID: userID,
            userName: userName,
            stars: stars,
            note: fields["note"] as? String,
            groupID: groupID,
            createdAt: createdAt
        )
    }

    private func group(from doc: FirestoreDocument) -> RatingGroup? {
        let fields = doc.fields
        guard
            let name = fields["name"] as? String,
            let inviteCode = fields["inviteCode"] as? String,
            let ownerUserID = fields["ownerUserID"] as? String,
            let createdAt = fields["createdAt"] as? Date
        else { return nil }
        return RatingGroup(
            id: doc.id,
            name: name,
            inviteCode: inviteCode,
            ownerUserID: ownerUserID,
            createdAt: createdAt,
            icon: fields["icon"] as? String ?? "🎵",
            description: fields["description"] as? String
        )
    }

    private static func randomInviteCode(length: Int = 6) -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }
}
