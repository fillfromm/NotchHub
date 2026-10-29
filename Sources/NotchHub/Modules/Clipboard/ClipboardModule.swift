import AppKit
import SwiftUI

struct ClipItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var pinned = false
    var date = Date()
    /// Optional short name for pinned snippets, e.g. "Email" or "LinkedIn".
    var label: String?
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
        // Text that is already pinned stays in the pinned list, not in history.
        if items.contains(where: { $0.text == text && $0.pinned }) { return }
        // Re-copying a history entry moves it to the top.
        items.removeAll { $0.text == text }
        items.insert(ClipItem(text: text), at: 0)
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

    /// Recent copies, newest first.
    var history: [ClipItem] { items.filter { !$0.pinned } }

    /// Items you keep on purpose (shown in the separate "Pinned" page).
    var pinnedItems: [ClipItem] { items.filter(\.pinned) }

    /// Adds a pinned snippet by hand (an email address, a profile link…).
    func addSnippet(label: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        items.insert(ClipItem(text: trimmed, pinned: true, label: name.isEmpty ? nil : name), at: 0)
        persist()
    }

    private func persist() {
        LocalStore.save(items, to: Self.file)
    }
}
