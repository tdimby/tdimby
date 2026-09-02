import Foundation

enum AppleMusicSearchError: LocalizedError {
    case transportFailed(String)
    case httpError(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .transportFailed(let detail):
            return "Couldn't reach Apple's music catalog: \(detail)"
        case .httpError(let status):
            return "Apple's music catalog returned an error (HTTP \(status))."
        case .decodingFailed:
            return "Apple returned something MusicRate couldn't understand."
        }
    }
}

/// Searches Apple's free, keyless iTunes Search API. Unlike Spotify's Web
/// API, this needs no registered app, no API key, and no login — it's a
/// plain public HTTP endpoint. The tradeoff: results and "Open in ___"
/// links point to Apple Music, not Spotify (see `MusicSource`), and there's
/// no real "browse/charts" endpoint without auth, so the starter list here
/// is just a broad search rather than actual curated new releases.
enum AppleMusicSearchService {
    private struct SearchResponse: Decodable {
        let results: [ResultItem]
    }

    private struct ResultItem: Decodable {
        let trackId: Int?
        let collectionId: Int?
        let trackName: String?
        let collectionName: String?
        let artistName: String?
        let artworkUrl100: String?
        let trackViewUrl: String?
        let collectionViewUrl: String?
    }

    static func search(query: String, type: SpotifyItemKind, limit: Int = 25) async throws -> [SpotifyItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.percentEncodedQueryItems = [
            URLQueryItem(name: "term", value: percentEncode(trimmed)),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: type == .album ? "album" : "song"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components.url else { throw AppleMusicSearchError.decodingFailed }

        let response: SearchResponse = try await get(url: url)
        return response.results.compactMap { mapItem($0, type: type) }
    }

    /// iTunes Search has no keyless "new releases" endpoint, so this just
    /// runs a broad search to seed the Search tab with something to browse.
    static func starterList(limit: Int = 25) async throws -> [SpotifyItem] {
        try await search(query: "top hits 2025", type: .track, limit: limit)
    }

    private static func mapItem(_ item: ResultItem, type: SpotifyItemKind) -> SpotifyItem? {
        switch type {
        case .album:
            guard let id = item.collectionId, let name = item.collectionName,
                  let viewURL = item.collectionViewUrl.flatMap(URL.init(string:))
            else { return nil }
            return SpotifyItem(
                spotifyID: "applemusic-album-\(id)",
                kind: .album,
                title: name,
                subtitle: item.artistName ?? "Album",
                artworkURL: item.artworkUrl100.flatMap { URL(string: higherResolution($0)) },
                spotifyURL: viewURL,
                source: .appleMusic
            )
        default:
            guard let id = item.trackId, let name = item.trackName,
                  let viewURL = item.trackViewUrl.flatMap(URL.init(string:))
            else { return nil }
            return SpotifyItem(
                spotifyID: "applemusic-track-\(id)",
                kind: .track,
                title: name,
                subtitle: item.artistName ?? "Track",
                artworkURL: item.artworkUrl100.flatMap { URL(string: higherResolution($0)) },
                spotifyURL: viewURL,
                source: .appleMusic
            )
        }
    }

    private static func higherResolution(_ artworkURLString: String) -> String {
        artworkURLString.replacingOccurrences(of: "100x100", with: "300x300")
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+#=?/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func get<T: Decodable>(url: URL) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw AppleMusicSearchError.transportFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AppleMusicSearchError.httpError(status)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppleMusicSearchError.decodingFailed
        }
    }
}
