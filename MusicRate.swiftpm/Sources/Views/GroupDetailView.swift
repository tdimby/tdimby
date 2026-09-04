import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GroupDetailView: View {
    let group: RatingGroup

    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var account: AccountStore
    @EnvironmentObject var weeklyPickStore: WeeklyPickStore
    @Environment(\.dismiss) private var dismiss

    @State private var feedItems: [FeedItem] = []
    @State private var members: [GroupMember] = []
    @State private var pointsEntries: [PointsEntry] = []
    @State private var hallOfFame: [ChampionEntry] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showLeaveConfirmation = false
    @State private var isLeaving = false
    @State private var showSettings = false
    @State private var didCopyCode = false

    private struct PointsEntry: Identifiable {
        var id: String { userID }
        let userID: String
        let name: String
        let ratings: Int
        let submissions: Int
        let wins: Int
        var points: Int { ratings + submissions * 2 + wins * 5 }
    }

    /// Reflects live edits made in `GroupSettingsView` - `group` itself is
    /// a fixed navigation-destination value, but `store.myGroups` gets
    /// updated in place after a rename/icon change/code regeneration.
    private var currentGroup: RatingGroup {
        store.myGroups.first(where: { $0.id == group.id }) ?? group
    }

    private var isOwner: Bool { currentGroup.ownerUserID == account.userID }

    var body: some View {
        List {
            header

            if !pointsEntries.isEmpty {
                Section {
                    ForEach(Array(pointsEntries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 10) {
                            Text(medalEmoji(for: index))
                                .font(.subheadline)
                                .frame(width: 24)
                            InitialsAvatarView(name: entry.name, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(entry.ratings) rated · \(entry.submissions) submitted · \(entry.wins) win\(entry.wins == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(entry.points)")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.green)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                Text("pts")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Points Leaderboard")
                } footer: {
                    Text("1 point per rating, 2 for submitting a weekly pick, 5 for winning one.")
                }
            }

            if !members.isEmpty {
                Section("Members (\(members.count))") {
                    ForEach(members) { member in
                        NavigationLink(value: member) {
                            HStack(spacing: 10) {
                                InitialsAvatarView(name: member.displayName, size: 32)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(member.displayName)
                                    if member.userID == currentGroup.ownerUserID {
                                        Text("Owner")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if member.userID == account.userID {
                                    Text("You")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(.secondary.opacity(0.12)))
                                }
                            }
                        }
                    }
                }
            }

            WeeklyPickSection(group: currentGroup)

            if !hallOfFame.isEmpty {
                Section {
                    ForEach(Array(hallOfFame.enumerated()), id: \.element.id) { index, entry in
                        if index == 0 {
                            NavigationLink(value: entry.item) {
                                ChampionSpotlightRow(entry: entry)
                            }
                        } else {
                            HStack(spacing: 10) {
                                Text(medalEmoji(for: index))
                                    .font(.subheadline)
                                    .frame(width: 24)
                                NavigationLink(value: entry.item) {
                                    SongRow(item: entry.item) {
                                        StaticStarsView(rating: entry.average)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Song Champions")
                } footer: {
                    Text("This group's best-rated songs of all time.")
                }
            }

            if isLoading {
                ProgressView()
            } else if feedItems.isEmpty {
                Text("No ratings in this group yet. Rate a song and choose \"\(currentGroup.name)\" as the audience.")
                    .foregroundStyle(.secondary)
            } else {
                Section("Recently Rated") {
                    ForEach(feedItems) { feedItem in
                        NavigationLink(value: feedItem.item) {
                            FeedItemRow(feedItem: feedItem)
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showLeaveConfirmation = true
                } label: {
                    if isLeaving {
                        ProgressView()
                    } else {
                        Text("Leave Group")
                    }
                }
                .disabled(isLeaving)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LinearGradient(colors: [Color.green.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom))
        .navigationTitle(currentGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SpotifyItem.self) { item in
            SongDetailView(item: item, group: currentGroup)
        }
        .navigationDestination(for: GroupMember.self) { member in
            let entry = pointsEntries.first(where: { $0.userID == member.userID })
            MemberDetailView(
                member: member,
                groupName: currentGroup.name,
                isOwner: member.userID == currentGroup.ownerUserID,
                ratings: entry?.ratings ?? 0,
                submissions: entry?.submissions ?? 0,
                wins: entry?.wins ?? 0,
                points: entry?.points ?? 0
            )
        }
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showSettings) {
            GroupSettingsView(group: currentGroup)
        }
        .confirmationDialog(
            "Leave \"\(currentGroup.name)\"?",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Group", role: .destructive) {
                Task { await leave() }
            }
        } message: {
            Text("You can rejoin later with the invite code.")
        }
        .alert(
            "MusicRate",
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private var header: some View {
        Section {
            VStack(spacing: 16) {
                Text(currentGroup.icon)
                    .font(.system(size: 40))
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(.white.opacity(0.2)))

                VStack(spacing: 4) {
                    Text(currentGroup.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if let description = currentGroup.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                }

                HStack(spacing: 22) {
                    heroStat("\(members.count)", "Members")
                    heroStat("\(feedItems.count)", "Ratings")
                    heroStat(hallOfFame.first.map { String(format: "%.1f", $0.average) } ?? "–", "Top Song")
                }

                VStack(spacing: 10) {
                    Button {
                        copyInviteCode()
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentGroup.inviteCode)
                                .font(.system(.body, design: .monospaced).weight(.bold))
                            Image(systemName: didCopyCode ? "checkmark" : "doc.on.doc")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.2)))
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: "Join my MusicRate group \"\(currentGroup.name)\" with invite code \(currentGroup.inviteCode)!") {
                        Label("Share Invite", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .background(groupGradient(for: currentGroup.name))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(minWidth: 56)
    }

    private func copyInviteCode() {
        #if canImport(UIKit)
        UIPasteboard.general.string = currentGroup.inviteCode
        #endif
        withAnimation { didCopyCode = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { didCopyCode = false }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        async let feedResult = store.feed(for: group)
        async let membersResult = store.members(of: group)
        do {
            feedItems = try await feedResult
            members = try await membersResult
        } catch {
            errorText = error.localizedDescription
        }
        // Wins need weeklyPickStore's leaderboard, so load it before
        // computing points rather than racing WeeklyPickSection's own
        // (redundant, harmless) load.
        await weeklyPickStore.load(for: group)
        async let pointsResult: Void = loadPoints()
        async let hallOfFameResult: Void = loadHallOfFame()
        await pointsResult
        await hallOfFameResult
    }

    /// Ranks the group's songs by all-time average rating, not just the
    /// most recent 50 the "Recently Rated" list uses - a real "best song
    /// ever posted here" competition rather than a recent-activity one.
    private func loadHallOfFame() async {
        let allRatings = await store.allRatings(for: group)
        let grouped = Dictionary(grouping: allRatings, by: \.songID)
        let songs = await store.songs(forIDs: grouped.keys)
        hallOfFame = grouped.compactMap { songID, ratings -> ChampionEntry? in
            guard let item = songs[songID] else { return nil }
            let average = Double(ratings.map(\.stars).reduce(0, +)) / Double(ratings.count)
            return ChampionEntry(item: item, average: average, count: ratings.count)
        }
        .sorted { $0.average == $1.average ? $0.count > $1.count : $0.average > $1.average }
        .prefix(5)
        .map { $0 }
    }

    /// Combines three sources into one points leaderboard: ratings posted
    /// to this group (`MusicStore`), songs submitted to weekly rounds, and
    /// weekly-round wins (both `WeeklyPickStore`).
    private func loadPoints() async {
        async let ratingCountsResult = store.ratingCounts(for: group)
        async let submissionCountsResult = weeklyPickStore.submissionCounts(for: group)
        let ratingCounts = await ratingCountsResult
        let submissionCounts = await submissionCountsResult
        let wins = Dictionary(uniqueKeysWithValues: weeklyPickStore.leaderboard.map { ($0.userID, $0.wins) })

        var userIDs = Set(ratingCounts.keys)
        userIDs.formUnion(submissionCounts.keys)
        userIDs.formUnion(wins.keys)

        pointsEntries = userIDs.map { userID in
            let name = ratingCounts[userID]?.name
                ?? submissionCounts[userID]?.name
                ?? members.first(where: { $0.userID == userID })?.displayName
                ?? "Member"
            return PointsEntry(
                userID: userID,
                name: name,
                ratings: ratingCounts[userID]?.count ?? 0,
                submissions: submissionCounts[userID]?.count ?? 0,
                wins: wins[userID] ?? 0
            )
        }
        .sorted { $0.points > $1.points }
    }

    private func leave() async {
        isLeaving = true
        defer { isLeaving = false }
        do {
            try await store.leaveGroup(group)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// One of the group's all-time best-rated songs - "Song Champions".
private struct ChampionEntry: Identifiable {
    var id: String { item.spotifyID }
    let item: SpotifyItem
    let average: Double
    let count: Int
}

/// The #1 spot in "Song Champions" gets a bigger, trophy-styled row
/// instead of just another list line, the same visual treatment as a
/// weekly-pick `WinnerRow`.
private struct ChampionSpotlightRow: View {
    let entry: ChampionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("All-Time Champion", systemImage: "crown.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            SongRow(item: entry.item) {
                StaticStarsView(rating: entry.average)
            }
            Text(String(format: "%.1f average · %d rating%@", entry.average, entry.count, entry.count == 1 ? "" : "s"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// A member's stats within one group - tapped from the Members list.
private struct MemberDetailView: View {
    let member: GroupMember
    let groupName: String
    let isOwner: Bool
    let ratings: Int
    let submissions: Int
    let wins: Int
    let points: Int

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    InitialsAvatarView(name: member.displayName, size: 88)
                    VStack(spacing: 4) {
                        Text(member.displayName)
                            .font(.title2.weight(.bold))
                        if isOwner {
                            Label("Group Owner", systemImage: "crown.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        Text("Joined \(member.joinedAt.formatted(.dateTime.month(.wide).day().year()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                HStack(spacing: 10) {
                    memberStat("\(ratings)", "Rated", "star.fill", .yellow)
                    memberStat("\(submissions)", "Submitted", "music.note", .blue)
                    memberStat("\(wins)", "Wins", "trophy.fill", .orange)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                HStack {
                    Text("Total Points")
                        .font(.headline)
                    Spacer()
                    Text("\(points)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("In \(groupName): 1 point per rating, 2 per weekly submission, 5 per weekly win.")
            }
        }
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func memberStat(_ value: String, _ label: String, _ systemImage: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.secondary.opacity(0.1))
        )
    }
}

/// Owner-only: rename the group, change its icon/description, or
/// invalidate the current invite code and issue a new one.
private struct GroupSettingsView: View {
    let group: RatingGroup
    @EnvironmentObject var store: MusicStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var isSaving = false
    @State private var isRegenerating = false
    @State private var errorText: String?
    @State private var showRegenerateConfirmation = false

    init(group: RatingGroup) {
        self.group = group
        _name = State(initialValue: group.name)
        _description = State(initialValue: group.description ?? "")
        _icon = State(initialValue: group.icon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        GroupIconView(name: name.isEmpty ? "?" : name, icon: icon, size: 64)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    GroupIconPicker(selection: $icon)
                }
                .listRowBackground(Color.clear)

                Section("Group Name") {
                    TextField("Group name", text: $name)
                }
                Section("Description") {
                    TextField("What's this group about? (optional)", text: $description, axis: .vertical)
                }

                Section {
                    HStack {
                        Text("Invite Code")
                        Spacer()
                        Text(group.inviteCode)
                            .font(.system(.body, design: .monospaced).weight(.bold))
                    }
                    Button(role: .destructive) {
                        showRegenerateConfirmation = true
                    } label: {
                        if isRegenerating {
                            ProgressView()
                        } else {
                            Label("Generate New Code", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isRegenerating)
                } footer: {
                    Text("Generating a new code immediately invalidates the old one — anyone who hasn't joined yet will need the new one.")
                }

                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Group Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .confirmationDialog(
                "Generate a new invite code?",
                isPresented: $showRegenerateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Generate New Code", role: .destructive) {
                    Task { await regenerate() }
                }
            } message: {
                Text("The current code (\(group.inviteCode)) will stop working.")
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.updateGroup(group, name: name, icon: icon, description: description)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func regenerate() async {
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            try await store.regenerateInviteCode(for: group)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
