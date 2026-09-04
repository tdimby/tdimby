import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: MusicStore
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            Group {
                if store.myGroups.isEmpty {
                    emptyState
                } else {
                    List(store.myGroups) { group in
                        NavigationLink(value: group) {
                            GroupRow(group: group, memberCount: store.groupMemberCounts[group.id])
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(backdrop)
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

    private var backdrop: some View {
        LinearGradient(colors: [Color.green.opacity(0.07), .clear], startPoint: .top, endPoint: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 88, height: 88)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.green)
            }
            Text("No groups yet")
                .font(.title3.weight(.bold))
            Text("Create a group and invite friends, or join one with an invite code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            VStack(spacing: 10) {
                Button {
                    showCreate = true
                } label: {
                    Label("Create a Group", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    showJoin = true
                } label: {
                    Label("Join with a Code", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
            .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .background(backdrop)
    }
}

private struct GroupRow: View {
    let group: RatingGroup
    let memberCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(group.icon)
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.2)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let description = group.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                pill("\(memberCount ?? 1) member\((memberCount ?? 1) == 1 ? "" : "s")", "person.2.fill")
                pill(group.inviteCode, "number")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(groupGradient(for: group.name))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    private func pill(_ text: String, _ systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.2)))
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
            Haptics.success()
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
            Haptics.success()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
