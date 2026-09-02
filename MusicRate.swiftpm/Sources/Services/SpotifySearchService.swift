import Foundation

enum SpotifySearchError: LocalizedError {
    case requestFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Couldn't reach Spotify's catalog. Check your connection and try again."
        case .decodingFailed:
            return "Spotify returned something MusicRate couldn't understand."
        }
    }
}

/// Searches Spotify's public catalog (and pulls a starter "browse" list of
/// new releases) using the Spotify Web API, authenticated via
/// `SpotifyAuthService`. Only track, album, and playlist search are wired
/// up here — that covers "browse without pasting a link."
enum SpotifySearchService {
    private struct ImageObject: Decodable { let url: String }
    private struct ExternalURLs: Decodable { let spotify: String }
    private struct ArtistRef: Decodable { let name: String }
    private struct AlbumRef: Decodable { let images: [ImageObject] }
    private struct OwnerRef: Decodable { let displayName: String?
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
    }

    private struct TrackObject: Decodable {
        let id: String
        let name: String
        let artists: [ArtistRef]
        let album: AlbumRef
        let externalURLs: ExternalURLs
        enum CodingKeys: String, CodingKey { case id, name, artists, album, externalURLs = "external_urls" }
    }

    private struct AlbumObject: Decodable {
        let id: String
        let name: String
        let artists: [ArtistRef]
        let images: [ImageObject]
        let externalURLs: ExternalURLs
        enum CodingKeys: String, CodingKey { case id, name, artists, images, externalURLs = "external_urls" }
    }

    private struct PlaylistObject: Decodable {
        let id: String
        let name: String
        let owner: OwnerRef
        let images: [ImageObject]
        let externalURLs: ExternalURLs
        enum CodingKeys: String, CodingKey { case id, name, owner, images, externalURLs = "external_urls" }
    }

    private struct Paging<T: Decodable>: Decodable {
        let items: [T?]
    }

    private struct SearchResponse: Decodable {
        let tracks: Paging<TrackObject>?
        let albums: Paging<AlbumObject>?
        let playlists: Paging<PlaylistObject>?
    }

    private struct NewReleasesResponse: Decodable {
        let albums: Paging<AlbumObject>
    }

    static func search(
        query: String,
        type: SpotifyItemKind,
        clientID: String,
        clientSecret: String
    ) async throws -> [SpotifyItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "limit", value: "25")
        ]

        let decoded: SearchResponse = try await get(url: components.url!, clientID: clientID, clientSecret: clientSecret)

        switch type {
        case .track:
            return (decoded.tracks?.items ?? []).compactMap { $0 }.map { track in
                SpotifyItem(
                    spotifyID: track.id,
                    kind: .track,
                    title: track.name,
                    subtitle: track.artists.map(\.name).joined(separator: ", "),
                    artworkURL: track.album.images.first.flatMap { URL(string: $0.url) },
                    spotifyURL: URL(string: track.externalURLs.spotify) ?? SpotifyLinkParser.canonicalURL(kind: .track, id: track.id)
                )
            }
        case .album:
            return (decoded.albums?.items ?? []).compactMap { $0 }.map { album in
                SpotifyItem(
                    spotifyID: album.id,
                    kind: .album,
                    title: album.name,
                    subtitle: album.artists.map(\.name).joined(separator: ", "),
                    artworkURL: album.images.first.flatMap { URL(string: $0.url) },
                    spotifyURL: URL(string: album.externalURLs.spotify) ?? SpotifyLinkParser.canonicalURL(kind: .album, id: album.id)
                )
            }
        case .playlist:
            return (decoded.playlists?.items ?? []).compactMap { $0 }.map { playlist in
                SpotifyItem(
                    spotifyID: playlist.id,
                    kind: .playlist,
                    title: playlist.name,
                    subtitle: playlist.owner.displayName.map { "By \($0)" } ?? "Playlist",
                    artworkURL: playlist.images.first.flatMap { URL(string: $0.url) },
                    spotifyURL: URL(string: playlist.externalURLs.spotify) ?? SpotifyLinkParser.canonicalURL(kind: .playlist, id: playlist.id)
                )
            }
        default:
            return []
        }
    }

    static func newReleases(clientID: String, clientSecret: String) async throws -> [SpotifyItem] {
        var components = URLComponents(string: "https://api.spotify.com/v1/browse/new-releases")!
        components.queryItems = [URLQueryItem(name: "limit", value: "25")]

        let decoded: NewReleasesResponse = try await get(url: components.url!, clientID: clientID, clientSecret: clientSecret)
        return decoded.albums.items.compactMap { $0 }.map { album in
            SpotifyItem(
                spotifyID: album.id,
                kind: .album,
                title: album.name,
                subtitle: album.artists.map(\.name).joined(separator: ", "),
                artworkURL: album.images.first.flatMap { URL(string: $0.url) },
                spotifyURL: URL(string: album.externalURLs.spotify) ?? SpotifyLinkParser.canonicalURL(kind: .album, id: album.id)
            )
        }
    }

    private static func get<T: Decodable>(url: URL, clientID: String, clientSecret: String) async throws -> T {
        let token = try await SpotifyAuthService.shared.accessToken(clientID: clientID, clientSecret: clientSecret)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SpotifySearchError.requestFailed
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SpotifySearchError.requestFailed
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SpotifySearchError.decodingFailed
        }
    }
}
