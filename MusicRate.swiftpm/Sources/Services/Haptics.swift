#if canImport(UIKit)
import UIKit
#endif

/// Tiny wrapper around UIKit's haptic feedback generators so call sites
/// don't need their own `#if canImport(UIKit)` guards.
enum Haptics {
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func light() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
