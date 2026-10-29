import SwiftUI

/// The three languages the translator offers.
enum TranslatorLanguage: String, CaseIterable, Identifiable {
    case en, ru, cs
    var id: String { rawValue }

    var name: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        case .cs: return "Čeština"
        }
    }
}

/// Quick word / phrase translation between English, Russian and Czech.
///
/// Uses the free MyMemory web service (no account or key), so the text you type
/// is sent to api.mymemory.translated.net. Nothing else leaves the Mac.
final class TranslatorModule: NotchModule, ObservableObject {
    let id = "translator"
    let title = "Translate"
    let icon = "character.bubble"

    @Published var source: TranslatorLanguage { didSet { save(); retranslate() } }
    @Published var target: TranslatorLanguage { didSet { save(); retranslate() } }
    @Published var input = "" { didSet { if input != oldValue { scheduleTranslation() } } }
    @Published private(set) var output = ""
    @Published private(set) var busy = false
    @Published private(set) var failed = false

    private var pending: DispatchWorkItem?
    private var generation = 0
    private var swapping = false

    init() {
        let d = UserDefaults.standard
        source = TranslatorLanguage(rawValue: d.string(forKey: "translator.source") ?? "") ?? .en
        target = TranslatorLanguage(rawValue: d.string(forKey: "translator.target") ?? "") ?? .ru
    }

    func makeView() -> AnyView { AnyView(TranslatorView(module: self)) }

    func swap() {
        let oldOutput = output
        swapping = true
        (source, target) = (target, source)
        swapping = false
        if oldOutput.isEmpty { scheduleTranslation() } else { input = oldOutput }
    }

    private func save() {
        UserDefaults.standard.set(source.rawValue, forKey: "translator.source")
        UserDefaults.standard.set(target.rawValue, forKey: "translator.target")
    }

    private func retranslate() {
        guard !swapping else { return }
        // Same language on both sides makes no sense: flip the other one.
        if source == target {
            target = TranslatorLanguage.allCases.first { $0 != source } ?? .en
            return
        }
        scheduleTranslation()
    }

    // MARK: Translation

    /// Waits for a short pause in typing before calling the service.
    private func scheduleTranslation() {
        pending?.cancel()
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { output = ""; failed = false; busy = false; return }
        let work = DispatchWorkItem { [weak self] in self?.translate(text) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func translate(_ text: String) {
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "\(source.rawValue)|\(target.rawValue)"),
        ]
        guard let url = components.url else { return }
        generation += 1
        let mine = generation
        busy = true; failed = false
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let translated = data
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                .flatMap { $0["responseData"] as? [String: Any] }
                .flatMap { $0["translatedText"] as? String }
            DispatchQueue.main.async {
                guard let self, mine == self.generation else { return } // a newer request replaced this one
                self.busy = false
                if let translated { self.output = Self.decode(translated) } else { self.failed = true }
            }
        }.resume()
    }

    /// The service sometimes returns HTML entities (&#39;).
    private static func decode(_ text: String) -> String {
        guard text.contains("&"),
              let data = text.data(using: .utf8),
              let attributed = try? NSAttributedString(data: data, options: [
                  .documentType: NSAttributedString.DocumentType.html,
                  .characterEncoding: String.Encoding.utf8.rawValue,
              ], documentAttributes: nil) else { return text }
        return attributed.string
    }

    func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }
}
