import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var searchType: SpotifyItemKind = .track
    @State private var results: [SpotifyItem] = []
    @State private var browseItems: [SpotifyItem] = []
    @State private var isSearching = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            resultsList
                .navigationTitle("Search")
                .searchable(text: $query, prompt: "Songs or albums…")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Type", selection: $searchType) {
                            Text("Songs").tag(SpotifyItemKind.track)
                            Text("Albums").tag(SpotifyItemKind.album)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .navigationDestination(for: SpotifyItem.self) { item in
                    SongDetailView(item: item, group: nil)
                }
                .task(id: "\(query)|\(searchType.rawValue)") {
                    await debouncedSearch()
                }
                .task {
                    await loadBrowseIfNeeded()
                }
        }
    }

    private var resultsList: some View {
        Group {
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if isSearching && results.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorText {
                    ContentUnavailableFallback(title: "Search failed", message: errorText, systemImage: "exclamationmark.triangle")
                } else if results.isEmpty {
                    ContentUnavailableFallback(title: "No results", message: "Nothing matched \"\(query)\".", systemImage: "magnifyingglass")
                } else {
                    List(results) { item in
                        NavigationLink(value: item) {
                            SongRow(item: item)
                        }
                    }
                    .listStyle(.plain)
                }
            } else if browseItems.isEmpty {
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableFallback(title: "Search for Music", message: "Find a song or album to rate — no need to paste a link.", systemImage: "magnifyingglass")
                }
            } else {
                List {
                    Section("Popular") {
                        ForEach(browseItems) { item in
                            NavigationLink(value: item) {
                                SongRow(item: item)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func debouncedSearch() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            return
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled else { return }
        await performSearch()
    }

    private func performSearch() async {
        isSearching = true
        errorText = nil
        defer { isSearching = false }
        do {
            results = try await AppleMusicSearchService.search(query: query, type: searchType)
        } catch {
            errorText = error.localizedDescription
            results = []
        }
    }

    private func loadBrowseIfNeeded() async {
        guard browseItems.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        browseItems = (try? await AppleMusicSearchService.starterList()) ?? []
    }
}
