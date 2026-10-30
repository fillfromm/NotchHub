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

    // Needed so text fields (clipboard snippets) can take keyboard focus
    // without the app becoming the active application.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// The app has no menu bar, so ⌘V / ⌘C / ⌘X / ⌘A / ⌘Z would have nothing to trigger them
    /// (and could reach the app underneath instead). Route them to the focused text field here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.shift) == .command,
              firstResponder is NSText else { return super.performKeyEquivalent(with: event) }
        let shift = event.modifierFlags.contains(.shift)
        let action: Selector?
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "v": action = #selector(NSText.paste(_:))
        case "c": action = #selector(NSText.copy(_:))
        case "x": action = #selector(NSText.cut(_:))
        case "a": action = #selector(NSText.selectAll(_:))
        case "z": action = Selector(shift ? "redo:" : "undo:")
        default: action = nil
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) { return true }
        return super.performKeyEquivalent(with: event)
    }
}
