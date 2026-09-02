import SwiftUI

struct SearchView: View {
    @EnvironmentObject var credentials: SpotifyCredentialsStore

    @State private var query = ""
    @State private var searchType: SpotifyItemKind = .track
    @State private var results: [SpotifyItem] = []
    @State private var browseItems: [SpotifyItem] = []
    @State private var isSearching = false
    @State private var errorText: String?
    @State private var showCredentialsSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if !credentials.hasCredentials {
                    missingCredentialsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Songs, albums, playlists…")
            .toolbar {
                if credentials.hasCredentials {
                    ToolbarItem(placement: .principal) {
                        Picker("Type", selection: $searchType) {
                            Text("Songs").tag(SpotifyItemKind.track)
                            Text("Albums").tag(SpotifyItemKind.album)
                            Text("Playlists").tag(SpotifyItemKind.playlist)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCredentialsSetup = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showCredentialsSetup) { SpotifyCredentialsView() }
            .navigationDestination(for: SpotifyItem.self) { item in
                SongDetailView(item: item, group: nil)
            }
            .task(id: "\(query)|\(searchType.rawValue)|\(credentials.hasCredentials)") {
                await debouncedSearch()
            }
            .task(id: credentials.hasCredentials) {
                await loadBrowseIfNeeded()
            }
        }
    }

    private var missingCredentialsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Add Spotify API Keys")
                .font(.headline)
            Text("Search needs your own free Spotify Web API keys — MusicRate doesn't ship with any.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Add Keys") { showCredentialsSetup = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    ContentUnavailableFallback(title: "Search Spotify", message: "Find a song, album, or playlist to rate — no need to paste a link.", systemImage: "magnifyingglass")
                }
            } else {
                List {
                    Section("New Releases") {
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
        guard credentials.hasCredentials else { return }
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
            results = try await SpotifySearchService.search(
                query: query,
                type: searchType,
                clientID: credentials.clientID,
                clientSecret: credentials.clientSecret
            )
        } catch {
            errorText = error.localizedDescription
            results = []
        }
    }

    private func loadBrowseIfNeeded() async {
        guard credentials.hasCredentials, browseItems.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        browseItems = (try? await SpotifySearchService.newReleases(
            clientID: credentials.clientID,
            clientSecret: credentials.clientSecret
        )) ?? []
    }
}
