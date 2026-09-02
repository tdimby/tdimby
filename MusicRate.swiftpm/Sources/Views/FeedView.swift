import SwiftUI

struct FeedView: View {
    @EnvironmentObject var store: MusicStore

    var body: some View {
        NavigationStack {
            Group {
                if store.worldwideFeed.isEmpty {
                    ContentUnavailableFallback(
                        title: "No ratings yet",
                        message: "Be the first to add a Spotify link and rate it for the world to see.",
                        systemImage: "globe"
                    )
                } else {
                    List(store.worldwideFeed) { feedItem in
                        NavigationLink(value: feedItem.item) {
                            FeedItemRow(feedItem: feedItem)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await store.refreshWorldwideFeed() }
                }
            }
            .navigationTitle("Worldwide")
            .navigationDestination(for: SpotifyItem.self) { item in
                SongDetailView(item: item, group: nil)
            }
        }
    }
}

/// A lightweight stand-in for `ContentUnavailableView` so this also renders
/// correctly on iOS 16 (the real view requires iOS 17).
struct ContentUnavailableFallback: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
