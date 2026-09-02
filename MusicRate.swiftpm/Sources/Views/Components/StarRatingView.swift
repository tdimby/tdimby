import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating = 5
    var size: CGFloat = 26
    var interactive = true

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...maxRating, id: \.self) { position in
                Image(systemName: position <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(position <= rating ? .yellow : .secondary.opacity(0.4))
                    .onTapGesture {
                        guard interactive else { return }
                        rating = position
                    }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) out of \(maxRating) stars")
        .accessibilityAdjustableAction { direction in
            guard interactive else { return }
            switch direction {
            case .increment: rating = min(maxRating, rating + 1)
            case .decrement: rating = max(0, rating - 1)
            default: break
            }
        }
    }
}

/// Compact, read-only star display for rows and summaries.
struct StaticStarsView: View {
    let rating: Double
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { position in
                Image(systemName: symbolName(for: position))
                    .font(.system(size: size))
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func symbolName(for position: Int) -> String {
        let fill = min(max(rating - Double(position - 1), 0), 1)
        if fill >= 0.75 {
            return "star.fill"
        } else if fill >= 0.25 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}
