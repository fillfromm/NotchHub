import AppKit
import ApplicationServices
import SwiftUI

/// A window of a running app, found through the Accessibility API.
struct WindowInfo: Identifiable {
    let id = UUID()
    let pid: pid_t
    let appName: String
    let icon: NSImage?
    let title: String
    let element: AXUIElement
}

/// A target area on the screen, as fractions of the usable screen (origin top-left).
struct WindowLayout: Identifiable {
    let id: String
    let name: String
    let x, y, w, h: CGFloat

    static let all: [WindowLayout] = [
        .init(id: "left",   name: "Left half",     x: 0,   y: 0,   w: 0.5, h: 1),
        .init(id: "right",  name: "Right half",    x: 0.5, y: 0,   w: 0.5, h: 1),
        .init(id: "top",    name: "Top half",      x: 0,   y: 0,   w: 1,   h: 0.5),
        .init(id: "bottom", name: "Bottom half",   x: 0,   y: 0.5, w: 1,   h: 0.5),
        .init(id: "full",   name: "Full screen",   x: 0,   y: 0,   w: 1,   h: 1),
        .init(id: "center", name: "Center",        x: 0.15, y: 0.1, w: 0.7, h: 0.8),
        .init(id: "tl",     name: "Top left",      x: 0,   y: 0,   w: 0.5, h: 0.5),
        .init(id: "tr",     name: "Top right",     x: 0.5, y: 0,   w: 0.5, h: 0.5),
        .init(id: "bl",     name: "Bottom left",   x: 0,   y: 0.5, w: 0.5, h: 0.5),
        .init(id: "br",     name: "Bottom right",  x: 0.5, y: 0.5, w: 0.5, h: 0.5),
        .init(id: "l23",    name: "Left two thirds",  x: 0,   y: 0, w: 2.0 / 3, h: 1),
        .init(id: "r13",    name: "Right third",      x: 2.0 / 3, y: 0, w: 1.0 / 3, h: 1),
        .init(id: "l13",    name: "Left third",       x: 0,   y: 0, w: 1.0 / 3, h: 1),
        .init(id: "r23",    name: "Right two thirds", x: 1.0 / 3, y: 0, w: 2.0 / 3, h: 1),
    ]
}

/// Lists open windows and snaps the chosen one to a part of the screen,
/// so two windows can sit side by side without dragging edges around.
/// Needs the Accessibility permission (System Settings → Privacy & Security).
final class WindowsModule: NotchModule, ObservableObject {
    let id = "windows"
    let title = "Windows"
    let icon = "rectangle.split.2x1"

    @Published private(set) var windows: [WindowInfo] = []
    @Published var selectedID: UUID?
    @Published private(set) var trusted = AXIsProcessTrusted()
    /// Name of the last layout applied, shown briefly as feedback.
    @Published private(set) var lastApplied: String?

    func makeView() -> AnyView { AnyView(WindowsView(module: self)) }

    var selected: WindowInfo? { windows.first { $0.id == selectedID } }

    // MARK: Permission

    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    // MARK: Window list

    /// Re-reads the windows of all regular apps. The app you were using before
    /// opening the notch is preselected.
    func refresh() {
        trusted = AXIsProcessTrusted()
        guard trusted else { windows = []; return }

        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var found: [WindowInfo] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { continue }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                  let list = value as? [AXUIElement] else { continue }
            for window in list where Self.isUsable(window) {
                found.append(WindowInfo(pid: app.processIdentifier, appName: app.localizedName ?? "App",
                                        icon: app.icon, title: Self.title(of: window), element: window))
            }
        }
        // Frontmost app first, then alphabetical.
        found.sort { ($0.pid == front ? 0 : 1, $0.appName) < ($1.pid == front ? 0 : 1, $1.appName) }
        windows = found
        if selected == nil { selectedID = found.first?.id }
    }

    /// Skips minimized windows and things like palettes without a title bar.
    private static func isUsable(_ window: AXUIElement) -> Bool {
        var minimized: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
           (minimized as? Bool) == true { return false }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &role)
        return (role as? String) == (kAXStandardWindowSubrole as String)
    }

    private static func title(of window: AXUIElement) -> String {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
        let title = (value as? String) ?? ""
        return title.isEmpty ? "Untitled window" : title
    }

    // MARK: Layout

    /// Moves and resizes the selected window into `layout` on the screen it is currently on.
    func apply(_ layout: WindowLayout) {
        guard let window = selected?.element else { return }
        // AX coordinates have their origin at the top-left of the primary screen;
        // NSScreen uses the bottom-left, so convert through the primary screen's height.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let screen = screenContaining(window: window, primaryHeight: primaryHeight)
        let area = screen.visibleFrame // excludes menu bar and Dock
        let axTop = primaryHeight - area.maxY

        var position = CGPoint(x: area.minX + area.width * layout.x, y: axTop + area.height * layout.y)
        var size = CGSize(width: area.width * layout.w, height: area.height * layout.h)

        // Size first, then position, then size again: some apps clamp the size at the old position.
        if let s = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s) }
        if let p = AXValueCreate(.cgPoint, &position) { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, p) }
        if let s = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s) }

        lastApplied = layout.name
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.lastApplied == layout.name { self?.lastApplied = nil }
        }
    }

    /// The screen under the window's top-left corner (falls back to the main screen).
    private func screenContaining(window: AXUIElement, primaryHeight: CGFloat) -> NSScreen {
        var value: CFTypeRef?
        var point = CGPoint.zero
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
           let value, CFGetTypeID(value) == AXValueGetTypeID() {
            AXValueGetValue(value as! AXValue, .cgPoint, &point)
        }
        let nsPoint = CGPoint(x: point.x + 20, y: primaryHeight - point.y - 20)
        return NSScreen.screens.first { $0.frame.contains(nsPoint) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// Brings the window to the front (so you see what you just placed).
    func raise(_ info: WindowInfo) {
        AXUIElementPerformAction(info.element, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: info.pid)?.activate()
    }
}
