import SwiftUI
import UniformTypeIdentifiers

/// The selected picture fills the tab. A thin bar on top switches pictures and adds / removes them.
struct PicturesView: View {
    @ObservedObject var module: PicturesModule
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 6) {
            toolbar
            ZStack {
                if let image = module.current {
                    Image(nsImage: image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 26)).foregroundStyle(.secondary)
                        Text("Drop a picture here, or use “Add”.\nIt will show every time you open the notch on this tab.")
                            .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: dropTargeted ? 2 : 0))
        }
        .padding(.horizontal, 6)
        // Dropping image files from Finder or a browser adds them.
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { module.add(urls: [url]) }
                }
            }
            return true
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            ForEach(Array(module.items.enumerated()), id: \.element.id) { index, item in
                let selected = module.selectedID == item.id
                Button { module.selectedID = item.id } label: {
                    Text("\(index + 1)").font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 22)
                        .background(Capsule().fill(Color.white.opacity(selected ? 0.25 : 0.08)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button { module.choosePictures() } label: { Label("Add", systemImage: "plus").font(.system(size: 11)) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            Button { module.addFromClipboard() } label: { Label("Paste", systemImage: "doc.on.clipboard").font(.system(size: 11)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Add the image from the clipboard")
            if module.current != nil {
                Button { module.removeSelected() } label: { Image(systemName: "trash").font(.system(size: 11)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Remove this picture")
            }
        }
        .padding(.horizontal, 4)
    }
}
