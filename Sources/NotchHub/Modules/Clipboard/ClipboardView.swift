import SwiftUI

/// One page at a time: recent text, or screenshots / copied images.
/// Buttons in the header switch between them.
struct ClipboardView: View {
    @ObservedObject var module: ClipboardModule
    private enum Page { case text, images }
    @State private var page: Page = .text
    @State private var copiedID: UUID?
    @State private var copiedImageID: UUID?

    var body: some View {
        VStack(spacing: 6) {
            header
            switch page {
            case .text: historyPage
            case .images: imagesPage
            }
        }
        .animation(.easeInOut(duration: 0.15), value: page)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            pageButton("Text", symbol: "text.alignleft", count: module.history.count, selected: page == .text) { page = .text }
            pageButton("Screenshots", symbol: "photo", count: module.images.count, selected: page == .images) { page = .images }
            Spacer()
            if page == .images {
                Button("Clear all") { module.clearImages() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .disabled(module.images.isEmpty)
            } else {
                Button("Clear history") { module.clearAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .disabled(module.history.isEmpty)
            }
        }
        .padding(.horizontal, 4)
    }

    private func pageButton(_ title: String, symbol: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text("\(title) \(count)")
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10).frame(height: 24)
            .background(Capsule().fill(Color.white.opacity(selected ? 0.2 : 0.07)))
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.6))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: History page

    @ViewBuilder
    private var historyPage: some View {
        if module.history.isEmpty {
            Spacer()
            Text("Copy some text and it will show up here.\nPin what you reuse often.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        } else {
            list(module.history)
        }
    }

    // MARK: Screenshots page

    @ViewBuilder
    private var imagesPage: some View {
        if module.folderBlocked {
            VStack(spacing: 6) {
                Text("macOS blocks NotchHub from reading the folder where screenshots are saved.")
                    .font(.system(size: 12)).foregroundStyle(.orange)
                Button("Allow in Files & Folders…") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!)
                }
                .controlSize(.small)
                Text("Turn on Desktop Folder for NotchHub, then take a new screenshot.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if module.images.isEmpty {
            Spacer()
            Text("Take a screenshot to the clipboard (⌃⌘⇧4) and it lands here.\nDrag it into any app, or click to copy it again.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(module.images) { imageCard($0) }
                }
                .padding(.horizontal, 4).padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func imageCard(_ image: ClipImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumb = module.thumbnail(for: image) {
                    Image(nsImage: thumb).resizable().scaledToFit()
                } else {
                    Color.white.opacity(0.1)
                }
            }
            .frame(width: 190, height: 112)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomLeading) {
                Text(copiedImageID == image.id ? "Copied" : "\(image.width)×\(image.height)")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .foregroundStyle(copiedImageID == image.id ? Color.green : Color.white.opacity(0.8))
                    .padding(4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                module.copy(image)
                copiedImageID = image.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if copiedImageID == image.id { copiedImageID = nil } }
            }
            // Dragging hands the PNG file to whatever app you drop it on.
            .onDrag { NSItemProvider(contentsOf: module.fileURL(for: image)) ?? NSItemProvider() }

            Button { module.remove(image) } label: {
                Image(systemName: "trash.fill").font(.system(size: 10))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.black.opacity(0.65)))
                    .foregroundStyle(.white)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(4)
            .help("Delete")
        }
    }

    // MARK: Rows

    private func list(_ items: [ClipItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(items) { row($0) }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ item: ClipItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 12))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if copiedID == item.id {
                Label("Copied", systemImage: "checkmark").font(.system(size: 10)).foregroundStyle(.green)
            }

            Button { module.remove(item) } label: {
                Image(systemName: "xmark").foregroundStyle(.white.opacity(0.35))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.07)))
        .contentShape(Rectangle())
        .onTapGesture {
            module.copy(item)
            copiedID = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if copiedID == item.id { copiedID = nil } }
        }
    }
}
