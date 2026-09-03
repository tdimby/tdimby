import SwiftUI

/// A colored circle showing someone's initials, since MusicRate has no
/// photo uploads. The color is derived from the name itself so the same
/// person always gets the same color across the app.
struct InitialsAvatarView: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let letters = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private var gradient: LinearGradient {
        let hue = Double(abs(name.hashValue) % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.55, brightness: 0.9),
                Color(hue: hue, saturation: 0.75, brightness: 0.65)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Circle()
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}
