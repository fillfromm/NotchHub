import AppKit
import SwiftUI

struct ClipItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var pinned = false
    var date = Date()
}

/// Text clipboard history (last ~30 items) with pinning. Stored locally only.
final class ClipboardModule: NotchModule, ObservableObject {
    let id = "clipboard"
    let title = "Clipboard"
    let icon = "doc.on.clipboard"

    /// Maximum number of unpinned items kept.
    static let limit = 30
    private static let file = "clipboard.json"

    @Published private(set) var items: [ClipItem]

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        items = LocalStore.load([ClipItem].self, from: Self.file) ?? []
        lastChangeCount = pasteboard.changeCount
        // The pasteboard has no change notification, so poll the (cheap) change counter.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPasteboard() }
        }
    }

    deinit { timer?.invalidate() }

    func makeView() -> AnyView { AnyView(ClipboardView(module: self)) }

    // MARK: Capture

    private func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Password managers mark secrets as concealed/transient: never record those.
        let types = pasteboard.types ?? []
        let hidden = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        guard !types.contains(where: { hidden.contains($0.rawValue) }) else { return }

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        add(text)
    }

    private func add(_ text: String) {
        // Re-copying an existing entry moves it to the top and keeps its pin.
        var pinned = false
        if let index = items.firstIndex(where: { $0.text == text }) {
            pinned = items[index].pinned
            items.remove(at: index)
        }
        items.insert(ClipItem(text: text, pinned: pinned), at: 0)
        trim()
        persist()
    }

    /// Keeps all pinned items plus the newest `limit` unpinned ones.
    private func trim() {
        var unpinned = 0
        items = items.filter { item in
            if item.pinned { return true }
            unpinned += 1
            return unpinned <= Self.limit
        }
    }

    // MARK: Actions

    func copy(_ item: ClipItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount // don't re-record our own copy
    }

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].pinned.toggle()
        persist()
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    /// Removes everything except pinned items.
    func clearAll() {
        items.removeAll { !$0.pinned }
        persist()
    }

    /// Pinned items first, then newest first.
    var sortedItems: [ClipItem] {
        items.filter(\.pinned) + items.filter { !$0.pinned }
    }

    private func persist() {
        LocalStore.save(items, to: Self.file)
    }
}
