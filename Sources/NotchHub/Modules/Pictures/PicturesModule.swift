import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PictureItem: Codable, Identifiable, Equatable {
    var id = UUID()
    /// File name inside the pictures folder.
    var file: String
}

/// Keeps a few pictures (a class schedule, a map, a plan…) and shows the selected one big.
/// Pick this tab once; from then on, hovering the notch shows the picture right away,
/// because the notch reopens on the last tab you used.
final class PicturesModule: NotchModule, ObservableObject {
    let id = "pictures"
    let title = "Pictures"
    let icon = "photo.on.rectangle"
    /// A taller notch so the picture is readable.
    var preferredContentHeight: CGFloat? { 400 }

    private static let indexFile = "pictures.json"
    private static let folderName = "pictures"

    @Published private(set) var items: [PictureItem]
    @Published var selectedID: UUID? {
        didSet { loadCurrent() }
    }
    @Published private(set) var current: NSImage?

    init() {
        items = LocalStore.load([PictureItem].self, from: Self.indexFile) ?? []
        selectedID = items.first?.id
        loadCurrent()
    }

    func makeView() -> AnyView { AnyView(PicturesView(module: self)) }

    // MARK: Adding

    /// Copies image files into the app's folder (the originals stay where they are).
    func add(urls: [URL]) {
        for url in urls {
            guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) else { continue }
            let name = "\(UUID().uuidString).\(url.pathExtension.lowercased())"
            let destination = LocalStore.folder(Self.folderName).appendingPathComponent(name)
            guard (try? FileManager.default.copyItem(at: url, to: destination)) != nil else { continue }
            let item = PictureItem(file: name)
            items.append(item)
            selectedID = item.id
        }
        save()
    }

    /// Adds the image currently on the clipboard (e.g. a screenshot).
    func addFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
              let rep = NSBitmapImageRep(data: data),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let name = "\(UUID().uuidString).png"
        guard (try? png.write(to: LocalStore.folder(Self.folderName).appendingPathComponent(name))) != nil else { return }
        let item = PictureItem(file: name)
        items.append(item)
        selectedID = item.id
        save()
    }

    /// File picker. The app isn't active by default, so bring it forward first.
    func choosePictures() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            if response == .OK { self?.add(urls: panel.urls) }
        }
    }

    func removeSelected() {
        guard let item = items.first(where: { $0.id == selectedID }) else { return }
        try? FileManager.default.removeItem(at: fileURL(item))
        items.removeAll { $0.id == item.id }
        selectedID = items.first?.id
        save()
    }

    // MARK: Display

    func fileURL(_ item: PictureItem) -> URL {
        LocalStore.folder(Self.folderName).appendingPathComponent(item.file)
    }

    /// Decodes a downscaled copy so large photos don't hold huge bitmaps in memory.
    func thumbnail(_ item: PictureItem, maxPixels: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL(item) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixels,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: .zero)
    }

    private func loadCurrent() {
        current = items.first { $0.id == selectedID }.flatMap { thumbnail($0, maxPixels: 2400) }
    }

    private func save() { LocalStore.save(items, to: Self.indexFile) }
}
