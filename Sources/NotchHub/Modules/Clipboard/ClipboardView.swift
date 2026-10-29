import SwiftUI

struct ClipboardView: View {
    @ObservedObject var module: ClipboardModule
    @State private var copiedID: UUID?

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(module.items.count) items")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("Clear unpinned") { module.clearAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .disabled(module.items.allSatisfy(\.pinned))
            }
            .padding(.horizontal, 4)

            if module.items.isEmpty {
                Spacer()
                Text("Copy some text and it will show up here.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(module.sortedItems) { row($0) }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        HStack(spacing: 8) {
            Button {
                module.togglePin(item)
            } label: {
                Image(systemName: item.pinned ? "pin.fill" : "pin")
                    .foregroundStyle(item.pinned ? Color.yellow : Color.white.opacity(0.4))
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .help(item.pinned ? "Unpin" : "Pin")

            Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 12))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if copiedID == item.id {
                Image(systemName: "checkmark").foregroundStyle(.green)
            }

            Button { module.remove(item) } label: {
                Image(systemName: "xmark").foregroundStyle(.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.07)))
        .contentShape(Rectangle())
        .onTapGesture {
            module.copy(item)
            copiedID = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if copiedID == item.id { copiedID = nil } }
        }
    }
}
