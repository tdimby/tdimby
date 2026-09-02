import Foundation

enum SpotifyMetadataError: LocalizedError {
    case invalidLink
    case requestFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "That doesn't look like a Spotify link. Copy a share link from the Spotify app and try again."
        case .requestFailed:
            return "Couldn't reach Spotify. Check your connection and try again."
        case .decodingFailed:
            return "Spotify returned something MusicRate couldn't understand."
        }
    }
}

/// Looks up display metadata (title, artist/owner, artwork) for a Spotify
/// link using Spotify's public oEmbed endpoint. This requires no API key or
/// login, so any pasted or shared link can be resolved immediately.
enum SpotifyMetadataService {
    private struct OEmbedResponse: Decodable {
        let title: String
        let thumbnailURL: String?

        enum CodingKeys: String, CodingKey {
            case title
            case thumbnailURL = "thumbnail_url"
        }
    }

    static func lookup(_ link: SpotifyLinkParser.ParsedLink) async throws -> SpotifyItem {
        var components = URLComponents(string: "https://open.spotify.com/oembed")!
        components.queryItems = [URLQueryItem(name: "url", value: link.canonicalURL.absoluteString)]
        guard let requestURL = components.url else { throw SpotifyMetadataError.invalidLink }

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await URLSession.shared.data(from: requestURL)
        } catch {
            throw SpotifyMetadataError.requestFailed
        }

        guard let http = urlResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SpotifyMetadataError.invalidLink
        }

        let response: OEmbedResponse
        do {
            response = try JSONDecoder().decode(OEmbedResponse.self, from: data)
        } catch {
            throw SpotifyMetadataError.decodingFailed
        }

        let artworkURL = response.thumbnailURL.flatMap(URL.init(string:))

        return SpotifyItem(
            spotifyID: link.spotifyID,
            kind: link.kind,
            title: response.title,
            subtitle: link.kind.displayName,
            artworkURL: artworkURL,
            spotifyURL: link.canonicalURL
        )
    }
}
