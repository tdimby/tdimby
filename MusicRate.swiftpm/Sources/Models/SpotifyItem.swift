import Foundation

enum SpotifyItemKind: String, Codable, CaseIterable, Hashable {
    case track, album, playlist, artist, show, episode

    var displayName: String {
        switch self {
        case .track: return "Track"
        case .album: return "Album"
        case .playlist: return "Playlist"
        case .artist: return "Artist"
        case .show: return "Show"
        case .episode: return "Episode"
        }
    }

    var systemImage: String {
        switch self {
        case .track: return "music.note"
        case .album: return "square.stack"
        case .playlist: return "music.note.list"
        case .artist: return "person.wave.2"
        case .show: return "mic"
        case .episode: return "waveform"
        }
    }
}

/// Where a `SpotifyItem` actually came from — pasted/looked-up links are
/// always real Spotify content, but search results come from Apple's free
/// catalog instead (see `AppleMusicSearchService`), so `spotifyURL` there
/// really opens Apple Music. Kept for accurate "Open in ___" labeling.
enum MusicSource: String, Codable, Hashable {
    case spotify
    case appleMusic

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }
}

/// A piece of music content (track, album, playlist, …) that can be rated.
/// Field names are Spotify-flavored since that's the app's primary source
/// (pasted links, and the `spotifyID`/`spotifyURL` shape), but `source`
/// tracks when an item actually came from elsewhere (see `MusicSource`).
struct SpotifyItem: Identifiable, Codable, Hashable {
    var id: String { spotifyID }
    let spotifyID: String
    let kind: SpotifyItemKind
    var title: String
    var subtitle: String
    var artworkURL: URL?
    var spotifyURL: URL
    var source: MusicSource
    /// A 30-second preview clip, when the source provides one (Apple Music
    /// search results only, for now — Spotify's oEmbed lookup doesn't
    /// include one). See `PreviewPlayer`.
    var previewURL: URL?

    init(spotifyID: String, kind: SpotifyItemKind, title: String, subtitle: String, artworkURL: URL?, spotifyURL: URL, source: MusicSource = .spotify, previewURL: URL? = nil) {
        self.spotifyID = spotifyID
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.spotifyURL = spotifyURL
        self.source = source
        self.previewURL = previewURL
    }

    private enum CodingKeys: String, CodingKey {
        case spotifyID, kind, title, subtitle, artworkURL, spotifyURL, source, previewURL
    }

    // Custom decode so songs saved before `source`/`previewURL` existed
    // still load instead of silently wiping out everyone's saved data.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spotifyID = try container.decode(String.self, forKey: .spotifyID)
        kind = try container.decode(SpotifyItemKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
        spotifyURL = try container.decode(URL.self, forKey: .spotifyURL)
        source = try container.decodeIfPresent(MusicSource.self, forKey: .source) ?? .spotify
        previewURL = try container.decodeIfPresent(URL.self, forKey: .previewURL)
    }
}
