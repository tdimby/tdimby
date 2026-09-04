import SwiftUI

/// A short celebratory burst of falling colored pieces. Overlay it on a
/// view and increment `trigger` (any `Int`, e.g. a counter) each time it
/// should fire - used for revealing a weekly-pick winner.
struct ConfettiView: View {
    let trigger: Int

    @State private var pieces: [Piece] = []
    @State private var animate = false

    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let color: Color
        let size: CGFloat
        let endRotation: Double
    }

    private static let colors: [Color] = [.yellow, .green, .pink, .blue, .orange, .purple, .mint]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.5)
                        .rotationEffect(.degrees(animate ? piece.endRotation : 0))
                        .position(x: piece.x, y: animate ? proxy.size.height + 40 : -20)
                        .opacity(animate ? 0 : 1)
                        .animation(.easeIn(duration: 1.8).delay(piece.delay), value: animate)
                }
            }
            .onChange(of: trigger) { _ in
                burst(in: proxy.size)
            }
            .onAppear {
                if trigger > 0 { burst(in: proxy.size) }
            }
        }
        .allowsHitTesting(false)
    }

    private func burst(in size: CGSize) {
        pieces = (0..<28).map { _ in
            Piece(
                x: CGFloat.random(in: 0...max(size.width, 1)),
                delay: Double.random(in: 0...0.3),
                color: Self.colors.randomElement()!,
                size: CGFloat.random(in: 6...11),
                endRotation: Double.random(in: 180...720)
            )
        }
        animate = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            animate = true
        }
    }
}
