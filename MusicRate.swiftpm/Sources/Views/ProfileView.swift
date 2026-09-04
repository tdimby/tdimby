import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: MusicStore
    @EnvironmentObject var account: AccountStore

    @State private var feedItems: [FeedItem] = []
    @State private var isLoading = true
    @State private var showEditName = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                header
                statsSection

                if totalRatingsGiven > 0 {
                    Section {
                        RatingBreakdownView(counts: starCounts)
                    } header: {
                        Text("Your Rating Breakdown")
                    }
                }

                activitySection

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationDestination(for: SpotifyItem.self) { item in
                SongDetailView(item: item, group: nil)
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showEditName) { EditNameView() }
            .confirmationDialog(
                "Sign out of MusicRate?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) { account.signOut() }
            }
        }
    }

    private var header: some View {
        Section {
            VStack(spacing: 14) {
                InitialsAvatarView(name: avatarSeed, size: 88)
                VStack(spacing: 4) {
                    Text(account.displayName.isEmpty ? "Add your name" : account.displayName)
                        .font(.title2.weight(.bold))
                    Text(account.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let memberSince = account.memberSince {
                        Text("Member since \(memberSince.formatted(.dateTime.month(.wide).year()))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Button {
                    showEditName = true
                } label: {
                    Label("Edit Name", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var statsSection: some View {
        Section {
            HStack(spacing: 10) {
                StatCard(value: "\(totalRatingsGiven)", label: "Ratings", systemImage: "star.fill", tint: .yellow)
                StatCard(value: "\(store.myGroups.count)", label: "Groups", systemImage: "person.3.fill", tint: .blue)
                StatCard(
                    value: totalRatingsGiven > 0 ? String(format: "%.1f", averageStarsGiven) : "–",
                    label: "Avg Given",
                    systemImage: "chart.bar.fill",
                    tint: .green
                )
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var activitySection: some View {
        if isLoading && feedItems.isEmpty {
            Section {
                ProgressView().frame(maxWidth: .infinity)
            }
        } else if feedItems.isEmpty {
            Section {
                Text("You haven't rated anything yet. Head to \"Search\" to get started.")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section {
                ForEach(feedItems.prefix(5)) { feedItem in
                    NavigationLink(value: feedItem.item) {
                        FeedItemRow(feedItem: feedItem)
                    }
                }
            } header: {
                Text("Recent Activity")
            } footer: {
                Text("See everything you've rated, with filters, in the Favorites tab.")
            }
        }
    }

    private var avatarSeed: String {
        account.displayName.isEmpty ? account.email : account.displayName
    }

    private var totalRatingsGiven: Int { store.myRatings.count }

    private var starCounts: [Int: Int] {
        Dictionary(grouping: store.myRatings, by: { $0.stars }).mapValues(\.count)
    }

    private var averageStarsGiven: Double {
        guard !store.myRatings.isEmpty else { return 0 }
        return Double(store.myRatings.map(\.stars).reduce(0, +)) / Double(store.myRatings.count)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        async let ratingsResult: Void = store.refreshMyRatings()
        async let groupsResult: Void = store.refreshMyGroups()
        await ratingsResult
        await groupsResult
        feedItems = await store.myFeedItems()
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
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

/// A compact 5-to-1-star horizontal bar chart of how many ratings the
/// current user has given at each star level.
private struct RatingBreakdownView: View {
    let counts: [Int: Int]

    private var maxCount: Int { max(counts.values.max() ?? 1, 1) }

    var body: some View {
        VStack(spacing: 8) {
            ForEach((1...5).reversed(), id: \.self) { stars in
                HStack(spacing: 8) {
                    Text("\(stars)")
                        .font(.caption.monospacedDigit())
                        .frame(width: 10)
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.yellow.opacity(0.7))
                            .frame(width: proxy.size.width * CGFloat(counts[stars] ?? 0) / CGFloat(maxCount))
                    }
                    .frame(height: 10)
                    Text("\(counts[stars] ?? 0)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EditNameView: View {
    @EnvironmentObject var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Name") {
                    TextField("Name shown on your ratings", text: $name)
                        .textInputAutocapitalization(.words)
                }
                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Edit Name")
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
            .onAppear { name = account.displayName }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await account.updateDisplayName(name)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
