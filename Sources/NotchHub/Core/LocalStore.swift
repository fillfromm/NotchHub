import Foundation

/// Tiny JSON persistence under ~/Library/Application Support/NotchHub.
/// Everything stays on this Mac; nothing is ever sent anywhere.
enum LocalStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("NotchHub", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Folder for larger files (e.g. screenshots), created on demand.
    static func folder(_ name: String) -> URL {
        let dir = directory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    static func loadText(from name: String) -> String {
        (try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)) ?? ""
    }

    static func saveText(_ text: String, to name: String) {
        try? text.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
}
