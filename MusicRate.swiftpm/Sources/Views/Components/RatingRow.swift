import SwiftUI

struct RatingRow: View {
    let rating: Rating

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                InitialsAvatarView(name: rating.userName, size: 26)
                Text(rating.userName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StaticStarsView(rating: Double(rating.stars))
            }
            if let note = rating.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(rating.createdAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct FeedItemRow: View {
    let feedItem: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SongRow(item: feedItem.item) {
                StaticStarsView(rating: Double(feedItem.rating.stars))
            }
            Text("rated by \(feedItem.rating.userName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
