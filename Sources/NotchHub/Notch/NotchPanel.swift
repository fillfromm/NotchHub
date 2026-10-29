import AppKit

/// Borderless, transparent panel that floats above the menu bar on every Space.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    // Needed so text fields (notes, calculator) can take keyboard focus
    // without the app becoming the active application.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
