import AppKit

/// Where the notch (or the fallback pill) is on screen and how big it is.
struct NotchGeometry: Equatable {
    var screenFrame: CGRect
    /// Physical notch width; 0 on screens without a notch.
    var notchWidth: CGFloat
    /// Height of the collapsed shape (notch height, or menu bar height for the pill).
    var height: CGFloat
    var hasNotch: Bool

    /// Extra width on each side of the notch when a module shows compact info.
    static let wingWidth: CGFloat = 88
    /// Width of the fallback pill on screens without a notch.
    static let pillWidth: CGFloat = 150
    static let activePillWidth: CGFloat = 240

    /// Visible width when collapsed.
    func collapsedWidth(showingInfo: Bool) -> CGFloat {
        if hasNotch {
            return notchWidth + (showingInfo ? 2 * Self.wingWidth : 0)
        }
        return showingInfo ? Self.activePillWidth : Self.pillWidth
    }

    /// Detects the notch screen (or falls back to the main screen with a pill).
    static func current() -> NotchGeometry {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let frame = screen.frame
        let inset = screen.safeAreaInsets.top

        if inset > 0 {
            var width: CGFloat = 185 // typical value if the aux areas are unavailable
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                width = frame.width - left.width - right.width
            }
            // +2pt so the black shape fully covers the notch edge.
            return NotchGeometry(screenFrame: frame, notchWidth: width + 2, height: inset, hasNotch: true)
        }
        return NotchGeometry(screenFrame: frame, notchWidth: 0, height: max(NSStatusBar.system.thickness, 24), hasNotch: false)
    }
}
