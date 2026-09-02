import SwiftUI

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 52

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.secondary.opacity(0.15))
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}
