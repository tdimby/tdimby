import AVFoundation
import Foundation

/// Plays a song's 30-second preview clip (see `SpotifyItem.previewURL`).
/// One shared player for the whole app, so starting a new preview always
/// stops whatever was playing before rather than overlapping audio.
@MainActor
final class PreviewPlayer: ObservableObject {
    static let shared = PreviewPlayer()

    @Published private(set) var playingID: String?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    private init() {}

    func toggle(_ item: SpotifyItem) {
        guard let url = item.previewURL else { return }
        if playingID == item.spotifyID {
            stop()
        } else {
            play(url: url, id: item.spotifyID)
        }
    }

    func isPlaying(_ item: SpotifyItem) -> Bool {
        playingID == item.spotifyID
    }

    func stop() {
        player?.pause()
        player = nil
        playingID = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func play(url: URL, id: String) {
        stop()
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        playingID = id
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        newPlayer.play()
    }
}
