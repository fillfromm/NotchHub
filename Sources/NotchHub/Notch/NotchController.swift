import AppKit
import Combine
import SwiftUI

/// Owns the panel and drives expand / collapse from mouse events.
///
/// The panel is resized to match the visible notch (so it never blocks menu bar
/// clicks around it), while SwiftUI animates the shape inside it.
final class NotchController {
    let state: NotchState
    let registry: ModuleRegistry
    private let settings: AppSettings
    private let panel = NotchPanel()
    private var monitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()
    private var pendingExpand: DispatchWorkItem?
    private var pendingCollapse: DispatchWorkItem?
    private var pendingShrink: DispatchWorkItem?

    private static let animationDuration: TimeInterval = 0.45

    init(registry: ModuleRegistry, settings: AppSettings = .shared) {
        self.registry = registry
        self.settings = settings
        self.state = NotchState(geometry: .current())

        let host = NSHostingView(rootView: NotchRootView(state: state, registry: registry))
        host.sizingOptions = []          // the controller owns the window size
        host.safeAreaRegions = []        // draw under the notch safe area
        panel.contentView = host
    }

    func start() {
        refreshCompact()
        applyFrame()
        panel.orderFrontRegardless()
        installMonitors()

        // Module / settings changes may change the compact info (and so the collapsed width).
        registry.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.refreshCompact() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.screenChanged() }
            .store(in: &cancellables)
    }

    // MARK: State sync

    private func refreshCompact() {
        let height = registry.selected?.preferredContentHeight
        if height != state.contentHeightOverride { state.contentHeightOverride = height }
        let info = registry.compactInfo
        if info != state.compact { state.compact = info }
        applyFrame() // also follows size changes while open (e.g. tab bar position)
    }

    private func screenChanged() {
        state.geometry = .current()
        applyFrame()
    }

    /// Anchors the panel at the top-center of the notch screen at the current visible size.
    private func applyFrame() {
        let size = state.currentSize
        let frame = state.geometry.screenFrame
        let rect = CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height,
                          width: size.width, height: size.height)
        if panel.frame != rect { panel.setFrame(rect, display: true) }
    }

    // MARK: Expand / collapse

    func expand() {
        pendingCollapse?.cancel(); pendingShrink?.cancel()
        guard !state.isExpanded else { return }
        // Grow the window first, then let SwiftUI animate the shape into it.
        let size = state.expandedSize
        let frame = state.geometry.screenFrame
        panel.setFrame(CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
        DispatchQueue.main.async { self.state.isExpanded = true }
    }

    func collapse(force: Bool = false) {
        pendingExpand?.cancel()
        guard state.isExpanded else { return }
        // Don't close while the user is typing, unless they clicked elsewhere.
        if !force, panel.isKeyWindow, panel.firstResponder is NSText { return }
        // A drag in progress (e.g. a screenshot being dragged out) must not lose its source view.
        if !force, NSEvent.pressedMouseButtons & 1 != 0 {
            schedule(\.pendingCollapse, after: 0.3) { [weak self] in self?.collapse() }
            return
        }
        panel.makeFirstResponder(nil)
        state.isExpanded = false
        // Shrink the window once the collapse animation has finished.
        pendingShrink?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.state.isExpanded else { return }
            self.applyFrame()
        }
        pendingShrink = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.animationDuration, execute: work)
    }

    // MARK: Mouse handling

    private func installMonitors() {
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        let global = NSEvent.addGlobalMonitorForEvents(matching: moves) { [weak self] _ in self?.mouseMoved() }
        let local = NSEvent.addLocalMonitorForEvents(matching: moves) { [weak self] event in
            self?.mouseMoved(); return event
        }
        let downGlobal = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in self?.mouseDown() }
        let downLocal = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.mouseDown(); return event
        }
        monitors = [global, local, downGlobal, downLocal].compactMap { $0 }
        panel.acceptsMouseMovedEvents = true
    }

    /// Region that opens the notch: the collapsed shape, slightly enlarged.
    private var triggerRect: CGRect {
        rect(for: state.collapsedSize).insetBy(dx: -6, dy: -6)
    }

    /// Region that keeps the notch open once expanded.
    private var keepOpenRect: CGRect {
        rect(for: state.expandedSize).insetBy(dx: -10, dy: -10)
    }

    private func rect(for size: CGSize) -> CGRect {
        let frame = state.geometry.screenFrame
        return CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    private func mouseMoved() {
        guard settings.expandMode == .hover else {
            return
        }
        let point = NSEvent.mouseLocation
        if state.isExpanded {
            if keepOpenRect.contains(point) {
                pendingCollapse?.cancel()
            } else if pendingCollapse == nil || pendingCollapse?.isCancelled == true {
                schedule(\.pendingCollapse, after: 0.25) { [weak self] in self?.collapse() }
            }
        } else if triggerRect.contains(point) {
            if pendingExpand == nil || pendingExpand?.isCancelled == true {
                schedule(\.pendingExpand, after: 0.12) { [weak self] in
                    guard let self, self.triggerRect.contains(NSEvent.mouseLocation) else { return }
                    self.expand()
                }
            }
        } else {
            pendingExpand?.cancel()
        }
    }

    private func mouseDown() {
        let point = NSEvent.mouseLocation
        if state.isExpanded {
            if !keepOpenRect.contains(point) { collapse(force: true) }
        } else if triggerRect.contains(point) {
            expand()
        }
    }

    /// Schedules a cancellable delayed action stored in one of the pending slots.
    private func schedule(_ slot: ReferenceWritableKeyPath<NotchController, DispatchWorkItem?>,
                          after delay: TimeInterval, _ action: @escaping () -> Void) {
        self[keyPath: slot]?.cancel()
        let work = DispatchWorkItem(block: action)
        self[keyPath: slot] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
