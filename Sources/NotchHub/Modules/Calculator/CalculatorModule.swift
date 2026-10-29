import Foundation
import SwiftUI

struct CalcEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var expression: String
    var result: String
}

/// Type an expression, press Return, get the result; history is kept between launches.
final class CalculatorModule: NotchModule, ObservableObject {
    let id = "calculator"
    let title = "Calculator"
    let icon = "plusminus.circle"

    private static let file = "calculator.json"
    private static let historyLimit = 30

    @Published var input = ""
    @Published private(set) var history: [CalcEntry]
    /// Live preview of the current input (or the error message).
    @Published private(set) var preview: String = ""
    @Published private(set) var previewIsError = false

    init() {
        history = LocalStore.load([CalcEntry].self, from: Self.file) ?? []
    }

    func makeView() -> AnyView { AnyView(CalculatorView(module: self)) }

    /// Called when the input changes: shows the result as you type.
    func updatePreview() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { preview = ""; previewIsError = false; return }
        do {
            preview = "= " + Self.format(try ExpressionParser.evaluate(text))
            previewIsError = false
        } catch {
            // Don't nag while the user is mid-expression.
            preview = ""
            previewIsError = false
        }
    }

    /// Commit the current input to history.
    func submit() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        do {
            let result = Self.format(try ExpressionParser.evaluate(text))
            history.insert(CalcEntry(expression: text, result: result), at: 0)
            if history.count > Self.historyLimit { history.removeLast(history.count - Self.historyLimit) }
            LocalStore.save(history, to: Self.file)
            input = result            // so you can keep calculating with the answer
            preview = ""; previewIsError = false
        } catch {
            preview = error.localizedDescription
            previewIsError = true
        }
    }

    func use(_ entry: CalcEntry) {
        input = entry.result
        updatePreview()
    }

    func clearHistory() {
        history = []
        LocalStore.save(history, to: Self.file)
    }

    /// Up to 10 decimals, no trailing zeros, no needless exponent for normal sizes.
    static func format(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "Undefined" }
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = "."
        formatter.maximumFractionDigits = 10
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
