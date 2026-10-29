import Foundation

/// One assistant response with its token usage, parsed from a Claude Code log line.
struct UsageEntry {
    var date: Date
    var input: Int
    var output: Int
    var cacheCreation: Int
    var cacheRead: Int

    /// Tokens that count as "work" (cache reads are tracked separately).
    var work: Int { input + output }
}

/// Aggregated numbers shown in the AI usage module.
struct UsageStats: Equatable {
    var blockWork = 0
    var blockMessages = 0
    var blockCached = 0
    /// End of the current 5-hour window, nil when no window is active.
    var blockEnd: Date?
    var todayWork = 0
    var todayMessages = 0
    var weekWork = 0
    var weekMessages = 0
    var weekCached = 0
}

/// Reads Claude Code's local JSONL session logs (`~/.claude/projects/**/*.jsonl`).
/// Purely local: no network, no keys.
enum UsageScanner {
    /// Claude's rate limits work on rolling 5-hour windows.
    static let blockLength: TimeInterval = 5 * 3600

    static var logRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".claude/projects"),
            home.appendingPathComponent(".config/claude/projects"),
        ]
    }

    static var hasData: Bool {
        logRoots.contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Parses all entries newer than `since`. Call from a background queue.
    static func scan(since: Date) -> [UsageEntry] {
        var entries: [UsageEntry] = []
        var seen = Set<String>() // a response is logged more than once; dedupe by message + request id
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()

        for root in logRoots {
            guard let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
            ) else { continue }

            for case let file as URL in walker where file.pathExtension == "jsonl" {
                // Skip files untouched since the window start: cheap way to avoid parsing old logs.
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let modified, modified < since { continue }
                guard let data = try? Data(contentsOf: file) else { continue }

                for line in data.split(separator: 10) {
                    guard let text = String(data: line, encoding: .utf8), text.contains("\"usage\"") else { continue }
                    guard let json = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                          json["type"] as? String == "assistant",
                          let message = json["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any],
                          let stamp = json["timestamp"] as? String,
                          let date = iso.date(from: stamp) ?? isoPlain.date(from: stamp),
                          date >= since else { continue }

                    if let messageID = message["id"] as? String, let requestID = json["requestId"] as? String {
                        if !seen.insert(messageID + ":" + requestID).inserted { continue }
                    }
                    entries.append(UsageEntry(
                        date: date,
                        input: usage["input_tokens"] as? Int ?? 0,
                        output: usage["output_tokens"] as? Int ?? 0,
                        cacheCreation: usage["cache_creation_input_tokens"] as? Int ?? 0,
                        cacheRead: usage["cache_read_input_tokens"] as? Int ?? 0
                    ))
                }
            }
        }
        return entries.sorted { $0.date < $1.date }
    }

    /// Turns raw entries into the numbers for the UI.
    static func stats(from entries: [UsageEntry], now: Date = Date()) -> UsageStats {
        var stats = UsageStats()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let weekStart = now.addingTimeInterval(-7 * 86400)

        for entry in entries {
            if entry.date >= weekStart {
                stats.weekWork += entry.work
                stats.weekMessages += 1
                stats.weekCached += entry.cacheCreation + entry.cacheRead
            }
            if entry.date >= startOfToday {
                stats.todayWork += entry.work
                stats.todayMessages += 1
            }
        }

        // Walk the entries to find the current 5-hour window: it starts at the
        // top of the hour of the first message after the previous window ended.
        var blockStart: Date?
        for entry in entries {
            if let start = blockStart, entry.date < start.addingTimeInterval(blockLength) { continue }
            let hour = calendar.dateInterval(of: .hour, for: entry.date)?.start ?? entry.date
            blockStart = hour
        }
        if let start = blockStart, now < start.addingTimeInterval(blockLength) {
            stats.blockEnd = start.addingTimeInterval(blockLength)
            for entry in entries where entry.date >= start {
                stats.blockWork += entry.work
                stats.blockMessages += 1
                stats.blockCached += entry.cacheCreation + entry.cacheRead
            }
        }
        return stats
    }
}
