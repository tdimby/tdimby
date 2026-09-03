import SwiftUI

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 56

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.secondary.opacity(0.15))
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }
}

struct SongRow: View {
    let item: SpotifyItem
    var trailing: AnyView

    init(item: SpotifyItem) {
        self.item = item
        self.trailing = AnyView(EmptyView())
    }

    init<Trailing: View>(item: SpotifyItem, @ViewBuilder trailing: () -> Trailing) {
        self.item = item
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: item.artworkURL)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: item.kind.systemImage)
                        .font(.caption2)
                    Text(item.subtitle)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if item.previewURL != nil {
                PreviewButton(item: item)
            }
            trailing
        }
        .padding(.vertical, 3)
    }
}

/// A tappable play/pause control for a 30-second preview clip. Placed
/// inside `SongRow`, which always lives in a `List` row - List specifically
/// supports a plain-style button reacting on its own without also
/// triggering the row's NavigationLink, unlike a bare HStack would.
struct PreviewButton: View {
    let item: SpotifyItem
    @ObservedObject private var player = PreviewPlayer.shared

    var body: some View {
        Button {
            player.toggle(item)
        } label: {
            Image(systemName: player.isPlaying(item) ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
    }
}
