import AppKit

enum ScriptResult {
    case success(NSAppleEventDescriptor)
    /// `code` is the AppleScript error number; -1743 means "not authorized" (Automation denied).
    case failure(code: Int, message: String)
}

/// Runs AppleScript off the main thread (scripts can block for a while) and
/// delivers the result on main. AppleScript is used instead of the private
/// MediaRemote framework, which is restricted on recent macOS versions.
final class AppleScriptRunner {
    static let shared = AppleScriptRunner()
    static let notAuthorized = -1743

    private let queue = DispatchQueue(label: "com.notchhub.applescript", qos: .utility)

    func run(_ source: String, completion: @escaping (ScriptResult) -> Void) {
        queue.async {
            var errorInfo: NSDictionary?
            let result: ScriptResult
            if let script = NSAppleScript(source: source) {
                let descriptor = script.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? -1
                    let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error"
                    result = .failure(code: code, message: message)
                } else {
                    result = .success(descriptor)
                }
            } else {
                result = .failure(code: -1, message: "Could not compile script")
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
}

/// Helpers for sending the user to the right System Settings pane.
enum PermissionHelper {
    static func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    static func openCalendarSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    }

    private static func open(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }
}
