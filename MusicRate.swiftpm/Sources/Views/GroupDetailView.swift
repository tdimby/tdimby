import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GroupDetailView: View {
    let group: RatingGroup

    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var account: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var feedItems: [FeedItem] = []
    @State private var members: [GroupMember] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showLeaveConfirmation = false
    @State private var isLeaving = false
    @State private var showSettings = false
    @State private var didCopyCode = false

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

            if !members.isEmpty {
                Section("Members (\(members.count))") {
                    ForEach(members) { member in
                        HStack(spacing: 10) {
                            InitialsAvatarView(name: member.displayName, size: 32)
                            Text(member.displayName)
                            if member.userID == currentGroup.ownerUserID {
                                Text("Owner")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if member.userID == account.userID {
                                Text("(You)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }

            WeeklyPickSection(group: currentGroup)

            if !topRated.isEmpty {
                Section {
                    ForEach(topRated, id: \.item.spotifyID) { entry in
                        NavigationLink(value: entry.item) {
                            SongRow(item: entry.item) {
                                StaticStarsView(rating: entry.average)
                            }
                        }
                    }
                } header: {
                    Text("Top Rated")
                } footer: {
                    Text("Based on this group's most recent ratings.")
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
        .navigationTitle(currentGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SpotifyItem.self) { item in
            SongDetailView(item: item, group: currentGroup)
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
            VStack(spacing: 12) {
                GroupIconView(name: currentGroup.name, icon: currentGroup.icon, size: 72)
                Text(currentGroup.name)
                    .font(.title2.weight(.bold))
                if let description = currentGroup.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    copyInviteCode()
                } label: {
                    HStack(spacing: 8) {
                        Text(currentGroup.inviteCode)
                            .font(.system(.body, design: .monospaced).weight(.bold))
                        Image(systemName: didCopyCode ? "checkmark" : "doc.on.doc")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                ShareLink(item: "Join my MusicRate group \"\(currentGroup.name)\" with invite code \(currentGroup.inviteCode)!") {
                    Label("Share Invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var topRated: [(item: SpotifyItem, average: Double, count: Int)] {
        let grouped = Dictionary(grouping: feedItems, by: { $0.item.spotifyID })
        return grouped.values
            .compactMap { items -> (item: SpotifyItem, average: Double, count: Int)? in
                guard let item = items.first?.item else { return nil }
                let stars = items.map(\.rating.stars)
                let average = Double(stars.reduce(0, +)) / Double(stars.count)
                return (item, average, stars.count)
            }
            .sorted { $0.average > $1.average }
            .prefix(5)
            .map { $0 }
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
