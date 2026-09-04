import SwiftUI

/// Your own rating history, front and center now that there's no
/// Worldwide feed to browse instead - stats up top, then a filterable
/// list of everything you've rated, richest ratings first when filtered.
struct FavoritesView: View {
    @EnvironmentObject var store: MusicStore
    @State private var feedItems: [FeedItem] = []
    @State private var isLoading = true
    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable {
        case all = "All"
        case five = "★5"
        case fourPlus = "★4+"
        case notes = "Notes"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && feedItems.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if feedItems.isEmpty {
                    emptyState
                } else {
                    List {
                        header
                        Section {
                            if filtered.isEmpty {
                                Text("Nothing matches this filter yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(filtered) { feedItem in
                                    NavigationLink(value: feedItem.item) {
                                        FeedItemRow(feedItem: feedItem)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: SpotifyItem.self) { item in
                SongDetailView(item: item, group: nil)
            }
            .task { await load() }
        }
    }

    private var header: some View {
        Section {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    statCard("\(feedItems.count)", "Rated", "star.fill", .yellow)
                    statCard(String(format: "%.1f", averageStars), "Average", "chart.bar.fill", .green)
                }
                HStack(spacing: 10) {
                    statCard("\(fiveStarCount)", "5★ Loves", "heart.fill", .pink)
                    statCard("\(currentStreak)", "Day Streak", "flame.fill", .orange)
                }
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.pink.opacity(0.15)).frame(width: 88, height: 88)
                Image(systemName: "heart.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.pink)
            }
            Text("Nothing rated yet")
                .font(.title3.weight(.bold))
            Text("Rate a song in Search or a group, and it'll show up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    private func statCard(_ value: String, _ label: String, _ systemImage: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
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

    private var filtered: [FeedItem] {
        switch filter {
        case .all: return feedItems
        case .five: return feedItems.filter { $0.rating.stars == 5 }
        case .fourPlus: return feedItems.filter { $0.rating.stars >= 4 }
        case .notes: return feedItems.filter { !($0.rating.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
        }
    }

    private var averageStars: Double {
        guard !feedItems.isEmpty else { return 0 }
        return Double(feedItems.map(\.rating.stars).reduce(0, +)) / Double(feedItems.count)
    }

    private var fiveStarCount: Int {
        feedItems.filter { $0.rating.stars == 5 }.count
    }

    /// Consecutive calendar days (ending today or yesterday - rating
    /// something today isn't required to keep yesterday's streak alive
    /// for the rest of today) with at least one rating.
    private var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(feedItems.map { calendar.startOfDay(for: $0.rating.createdAt) })
        guard !days.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else {
                return 0
            }
            day = yesterday
        }

        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        await store.refreshMyRatings()
        feedItems = await store.myFeedItems()
    }
}
