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

/// A piece of Spotify content (track, album, playlist, …) that can be rated.
struct SpotifyItem: Identifiable, Codable, Hashable {
    var id: String { spotifyID }
    let spotifyID: String
    let kind: SpotifyItemKind
    var title: String
    var subtitle: String
    var artworkURL: URL?
    var spotifyURL: URL

    init(spotifyID: String, kind: SpotifyItemKind, title: String, subtitle: String, artworkURL: URL?, spotifyURL: URL) {
        self.spotifyID = spotifyID
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.spotifyURL = spotifyURL
    }
}
