import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var searchType: SpotifyItemKind = .track
    @State private var results: [SpotifyItem] = []
    @State private var browseItems: [SpotifyItem] = []
    @State private var browseItemsType: SpotifyItemKind?
    @State private var browseError: String?
    @State private var isSearching = false
    @State private var errorText: String?
    @State private var showPasteLink = false

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
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showPasteLink = true
                        } label: {
                            Label("Paste a Spotify Link", systemImage: "link")
                        }
                    }
                }
                .navigationDestination(for: SpotifyItem.self) { item in
                    SongDetailView(item: item, group: nil)
                }
                .task(id: "\(query)|\(searchType.rawValue)") {
                    await debouncedSearch()
                }
                .task(id: searchType) {
                    await loadBrowseIfNeeded()
                }
                .sheet(isPresented: $showPasteLink) {
                    AddLinkView()
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
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No results")
                            .font(.headline)
                        Text("Nothing matched \"\(query)\".")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            showPasteLink = true
                        } label: {
                            Label("Paste a Spotify Link Instead", systemImage: "link")
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
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
                } else if let browseError {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Couldn't load music")
                            .font(.headline)
                        Text(browseError)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await reloadBrowse() }
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .padding(.top, 4)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableFallback(title: "Search for Music", message: "Find a song or album to rate — no need to paste a link.", systemImage: "magnifyingglass")
                }
            } else {
                List {
                    Section(searchType == .album ? "Popular Albums" : "Popular Right Now") {
                        ForEach(browseItems) { item in
                            NavigationLink(value: item) {
                                SongRow(item: item)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await reloadBrowse() }
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

    /// The browse list ("Popular Right Now"/"Popular Albums") used to be
    /// fetched once and never again, always as tracks - so switching the
    /// Songs/Albums picker with an empty search field just kept showing
    /// the same track list under an album-shaped section, which looked
    /// broken. It's now keyed to `searchType` and reloads whenever that
    /// changes.
    private func loadBrowseIfNeeded() async {
        guard browseItemsType != searchType else { return }
        browseItems = []
        browseItemsType = nil
        await reloadBrowse()
    }

    private func reloadBrowse() async {
        isSearching = true
        browseError = nil
        defer { isSearching = false }
        do {
            browseItems = try await AppleMusicSearchService.starterList(type: searchType)
            browseItemsType = searchType
        } catch {
            browseError = error.localizedDescription
        }
    }
}
