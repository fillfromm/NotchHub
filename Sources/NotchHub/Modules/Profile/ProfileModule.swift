import AppKit
import SwiftUI

/// Kind of a profile entry; drives the icon and the filter chips.
enum ProfileKind: String, Codable, CaseIterable, Identifiable {
    case email, phone, link, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        case .link: return "Links"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .link: return "link"
        case .other: return "text.quote"
        }
    }

    /// Best guess from the value, used when you don't pick a kind yourself.
    static func detect(_ value: String) -> ProfileKind {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.contains("@") && !text.contains("/") && !text.contains(" ") { return .email }
        if text.hasPrefix("http") || text.hasPrefix("www.") || text.contains("linkedin.com") || text.contains("github.com") { return .link }
        let digits = text.filter(\.isNumber)
        if digits.count >= 7 && text.allSatisfy({ $0.isNumber || "+-() ".contains($0) }) { return .phone }
        return .other
    }
}

struct ProfileField: Codable, Identifiable, Equatable {
    var id = UUID()
    var label: String
    var value: String
    var kind: ProfileKind
}

/// Your reusable details (emails, phone, profile links…): filter, click to copy.
/// Handy for job applications and forms.
final class ProfileModule: NotchModule, ObservableObject {
    let id = "profile"
    let title = "Profile"
    let icon = "person.text.rectangle"

    private static let file = "profile.json"
    @Published private(set) var fields: [ProfileField]

    init() {
        fields = LocalStore.load([ProfileField].self, from: Self.file) ?? []
    }

    func makeView() -> AnyView { AnyView(ProfileView(module: self)) }

    func add(label: String, value: String, kind: ProfileKind?) {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = kind ?? ProfileKind.detect(text)
        fields.append(ProfileField(label: name.isEmpty ? resolved.label : name, value: text, kind: resolved))
        save()
    }

    func remove(_ field: ProfileField) {
        fields.removeAll { $0.id == field.id }
        save()
    }

    func copy(_ field: ProfileField) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(field.value, forType: .string)
    }

    private func save() { LocalStore.save(fields, to: Self.file) }
}
