import AppKit
import SwiftUI

struct ClipItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var date = Date()
}

/// A copied image (typically a screenshot taken with Ctrl+Cmd+Shift+4), kept as a PNG file.
struct ClipImage: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var width: Int
    var height: Int
}

/// Clipboard history: text (last ~30, with pinning) and images. Stored locally only.
final class ClipboardModule: NotchModule, ObservableObject {
    let id = "clipboard"
    let title = "Clipboard"
    let icon = "doc.on.clipboard"

    /// Maximum number of text items kept.
    static let limit = 30
    /// Maximum number of screenshots kept (older ones are deleted from disk).
    static let imageLimit = 20
    private static let file = "clipboard.json"
    private static let imagesFile = "clipboard-images.json"
    private static let imagesFolder = "screenshots"

    @Published private(set) var items: [ClipItem]
    @Published private(set) var images: [ClipImage]
    /// True when macOS doesn't let us read the screenshot folder (Files & Folders permission).
    @Published private(set) var folderBlocked = false
    private var thumbnails: [UUID: NSImage] = [:]

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private var tick = 0
    private var knownScreenshots: Set<String> = []

    init() {
        items = LocalStore.load([ClipItem].self, from: Self.file) ?? []
        images = LocalStore.load([ClipImage].self, from: Self.imagesFile) ?? []
        lastChangeCount = pasteboard.changeCount
        // The pasteboard has no change notification, so poll the (cheap) change counter.
        knownScreenshots = Set(screenshotFiles().map(\.lastPathComponent))
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkPasteboard()
                self?.tick += 1
                if let self, self.tick % 2 == 0 { self.checkScreenshotFolder() }
            }
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

        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(text)
        } else if types.contains(.png) || types.contains(.tiff) {
            addImage()
        }
    }

    // MARK: Images

    func fileURL(for image: ClipImage) -> URL {
        LocalStore.folder(Self.imagesFolder).appendingPathComponent("\(image.id.uuidString).png")
    }

    /// Reads the image from the pasteboard and stores it as a PNG.
    private func addImage() {
        guard let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else { return }
        store(imageData: data)
    }

    // MARK: Screenshot files

    /// Where macOS saves screenshots: the user's chosen folder, or the Desktop.
    private var screenshotFolder: URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// Image files in that folder that look like system screenshots (English and Russian names).
    private func screenshotFiles() -> [URL] {
        let prefixes = ["screenshot", "screen shot", "снимок экрана", "скриншот"]
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: screenshotFolder, includingPropertiesForKeys: [.contentModificationDateKey])
            if folderBlocked { folderBlocked = false }
        } catch {
            // Usually macOS denying access to Desktop / Documents until the user allows it.
            if !folderBlocked { folderBlocked = true }
            return []
        }
        return files.filter { url in
            let name = url.lastPathComponent.lowercased()
            return ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased())
                && prefixes.contains { name.hasPrefix($0) }
        }
    }

    /// Imports screenshots that appeared since the last check.
    private func checkScreenshotFolder() {
        guard AppSettings.shared.importScreenshots else { return }
        for url in screenshotFiles() where !knownScreenshots.contains(url.lastPathComponent) {
            // Skip files still being written.
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let modified, Date().timeIntervalSince(modified) > 1 else { continue }
            knownScreenshots.insert(url.lastPathComponent)
            guard let data = try? Data(contentsOf: url) else { continue }
            store(imageData: data)
            if AppSettings.shared.trashScreenshots { try? FileManager.default.trashItem(at: url, resultingItemURL: nil) }
        }
    }

    /// Converts image data to PNG and adds it to the list.
    private func store(imageData data: Data) {
        guard let rep = NSBitmapImageRep(data: data),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let image = ClipImage(width: rep.pixelsWide, height: rep.pixelsHigh)
        do { try png.write(to: fileURL(for: image), options: .atomic) } catch { return }
        images.insert(image, at: 0)
        while images.count > Self.imageLimit { deleteFiles(of: images.removeLast()) }
        persistImages()
    }

    /// Small preview, decoded once per image.
    func thumbnail(for image: ClipImage) -> NSImage? {
        if let cached = thumbnails[image.id] { return cached }
        guard let source = CGImageSourceCreateWithURL(fileURL(for: image) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 360,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else { return nil }
        let thumb = NSImage(cgImage: cg, size: .zero)
        thumbnails[image.id] = thumb
        return thumb
    }

    /// Puts the image back on the pasteboard, ready to paste.
    func copy(_ image: ClipImage) {
        guard let nsImage = NSImage(contentsOf: fileURL(for: image)) else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        lastChangeCount = pasteboard.changeCount
    }

    func remove(_ image: ClipImage) {
        deleteFiles(of: image)
        images.removeAll { $0.id == image.id }
        persistImages()
    }

    func clearImages() {
        images.forEach(deleteFiles(of:))
        images.removeAll()
        persistImages()
    }

    private func deleteFiles(of image: ClipImage) {
        thumbnails[image.id] = nil
        try? FileManager.default.removeItem(at: fileURL(for: image))
    }

    private func persistImages() {
        LocalStore.save(images, to: Self.imagesFile)
    }

    private func add(_ text: String) {
        // Re-copying a history entry moves it to the top.
        items.removeAll { $0.text == text }
        items.insert(ClipItem(text: text), at: 0)
        trim()
        persist()
    }

    /// Keeps the newest `limit` items.
    private func trim() {
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
    }

    // MARK: Actions

    func copy(_ item: ClipItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount // don't re-record our own copy
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    /// Recent copies, newest first.
    var history: [ClipItem] { items }

    private func persist() {
        LocalStore.save(items, to: Self.file)
    }
}
