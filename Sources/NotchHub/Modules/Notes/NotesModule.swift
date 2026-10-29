import SwiftUI

/// One scratchpad note, saved locally as you type.
final class NotesModule: NotchModule, ObservableObject {
    let id = "notes"
    let title = "Quick notes"
    let icon = "note.text"

    private static let file = "notes.txt"
    private var saveWork: DispatchWorkItem?

    @Published var text: String {
        didSet { scheduleSave() }
    }

    init() {
        text = LocalStore.loadText(from: Self.file)
    }

    func makeView() -> AnyView { AnyView(NotesView(module: self)) }

    /// Debounced so we don't write to disk on every keystroke.
    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = text
        let work = DispatchWorkItem { LocalStore.saveText(snapshot, to: Self.file) }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}

struct NotesView: View {
    @ObservedObject var module: NotesModule

    var body: some View {
        TextEditor(text: $module.text)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
            .overlay(alignment: .topLeading) {
                if module.text.isEmpty {
                    Text("Jot something down…")
                        .font(.system(size: 13)).foregroundStyle(.tertiary)
                        .padding(.top, 8).padding(.leading, 13)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 6)
    }
}
