import Foundation

/// The name shown next to your ratings. Kept locally — CloudKit's real
/// identity APIs need extra entitlements this Playgrounds app doesn't
/// request, so MusicRate asks for a nickname instead.
final class DisplayNameStore: ObservableObject {
    private static let key = "musicrate.displayName"

    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: Self.key) }
    }

    init() {
        name = UserDefaults.standard.string(forKey: Self.key) ?? ""
    }

    var hasChosenName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
