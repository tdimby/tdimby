import SwiftUI

/// Preset emoji a group can use as its icon - simpler and more reliable
/// than trying to embed a full emoji keyboard in a Swift Playgrounds app.
let groupIconOptions = ["🎵", "🎧", "🎤", "🎸", "🥁", "🎹", "🌍", "🔥", "⭐️", "🎬", "🍿", "🎮"]

/// A rounded-square icon for a group: its chosen emoji on a color derived
/// from the group's name, so groups stay visually distinct in a list.
struct GroupIconView: View {
    let name: String
    let icon: String
    var size: CGFloat = 44

    private var gradient: LinearGradient {
        let hue = Double(abs(name.hashValue) % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.5, brightness: 0.85),
                Color(hue: hue, saturation: 0.65, brightness: 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(icon)
                    .font(.system(size: size * 0.5))
            )
    }
}

/// A grid of preset emoji to pick a group's icon from.
struct GroupIconPicker: View {
    @Binding var selection: String
    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(groupIconOptions, id: \.self) { icon in
                Button {
                    selection = icon
                } label: {
                    Text(icon)
                        .font(.system(size: 24))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(selection == icon ? Color.green.opacity(0.25) : Color.secondary.opacity(0.08))
                        )
                        .overlay(
                            Circle().stroke(selection == icon ? Color.green : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
