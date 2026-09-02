import Foundation

/// Recognizes Spotify share links (`https://open.spotify.com/...`) and URIs
/// (`spotify:track:...`) pasted or shared into the app.
enum SpotifyLinkParser {
    struct ParsedLink: Equatable {
        let kind: SpotifyItemKind
        let spotifyID: String
        let canonicalURL: URL
    }

    private static let webLinkRegex = try! NSRegularExpression(
        pattern: #"open\.spotify\.com(?:/intl-[a-zA-Z-]+)?/(track|album|playlist|artist|show|episode)/([A-Za-z0-9]+)"#
    )

    private static let uriRegex = try! NSRegularExpression(
        pattern: #"spotify:(track|album|playlist|artist|show|episode):([A-Za-z0-9]+)"#
    )

    /// Finds the first Spotify link inside arbitrary text (e.g. a full share
    /// message like "Check this out! https://open.spotify.com/track/abc123?si=xyz").
    static func firstLink(in text: String) -> ParsedLink? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        if let match = webLinkRegex.firstMatch(in: text, range: range),
           let kindRange = Range(match.range(at: 1), in: text),
           let idRange = Range(match.range(at: 2), in: text) {
            let kind = SpotifyItemKind(rawValue: String(text[kindRange]))!
            let id = String(text[idRange])
            return ParsedLink(kind: kind, spotifyID: id, canonicalURL: canonicalURL(kind: kind, id: id))
        }

        if let match = uriRegex.firstMatch(in: text, range: range),
           let kindRange = Range(match.range(at: 1), in: text),
           let idRange = Range(match.range(at: 2), in: text) {
            let kind = SpotifyItemKind(rawValue: String(text[kindRange]))!
            let id = String(text[idRange])
            return ParsedLink(kind: kind, spotifyID: id, canonicalURL: canonicalURL(kind: kind, id: id))
        }

        return nil
    }

    static func canonicalURL(kind: SpotifyItemKind, id: String) -> URL {
        URL(string: "https://open.spotify.com/\(kind.rawValue)/\(id)")!
    }

    /// A link to Spotify's own search for `text` (e.g. "title artist") —
    /// not a direct link to a specific catalog item like `canonicalURL`,
    /// but useful when all we know is a title/artist from another source
    /// (like Apple Music search results) rather than a real Spotify ID.
    static func searchURL(for text: String) -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "%")
        let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
        return URL(string: "https://open.spotify.com/search/\(encoded)") ?? URL(string: "https://open.spotify.com/search")!
    }
}
