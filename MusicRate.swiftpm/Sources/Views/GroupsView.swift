import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: MusicStore
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            Group {
                if store.myGroups.isEmpty {
                    ContentUnavailableFallback(
                        title: "No groups yet",
                        message: "Create a group and invite friends, or join one with an invite code.",
                        systemImage: "person.3"
                    )
                } else {
                    List(store.myGroups) { group in
                        NavigationLink(value: group) {
                            GroupRow(group: group, memberCount: store.groupMemberCounts[group.id])
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await store.refreshMyGroups() }
                }
            }
            .navigationTitle("Groups")
            .navigationDestination(for: RatingGroup.self) { group in
                GroupDetailView(group: group)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showCreate = true
                        } label: {
                            Label("Create Group", systemImage: "plus.circle")
                        }
                        Button {
                            showJoin = true
                        } label: {
                            Label("Join Group", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) { CreateGroupView() }
            .sheet(isPresented: $showJoin) { JoinGroupView() }
        }
    }
}

private struct GroupRow: View {
    let group: RatingGroup
    let memberCount: Int?

    var body: some View {
        HStack(spacing: 12) {
            GroupIconView(name: group.name, icon: group.icon, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.body.weight(.semibold))
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 12) {
                    Label("\(memberCount ?? 1)", systemImage: "person.2.fill")
                    Label(group.inviteCode, systemImage: "number")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateGroupView: View {
    @EnvironmentObject var store: MusicStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var icon = "🎵"
    @State private var isSaving = false
    @State private var errorText: String?

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
                    TextField("e.g. Roommates, Book Club", text: $name)
                }
                Section {
                    TextField("What's this group about? (optional)", text: $description, axis: .vertical)
                } header: {
                    Text("Description")
                }
                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await create() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Create") }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func create() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await store.createGroup(name: name, icon: icon, description: description)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct JoinGroupView: View {
    @EnvironmentObject var store: MusicStore
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 34))
                            .foregroundStyle(.green)
                        Text("Ask whoever's group it is for their invite code.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("Invite Code") {
                    TextField("6-character code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }
            }
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await join() }
                    } label: {
                        if isJoining { ProgressView() } else { Text("Join") }
                    }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining)
                }
            }
        }
    }

    private func join() async {
        isJoining = true
        defer { isJoining = false }
        do {
            _ = try await store.joinGroup(inviteCode: code)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
