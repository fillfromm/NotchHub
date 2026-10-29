import AppKit
import SwiftUI

/// One editable line: a name you choose ("Phone", "LinkedIn"…) and its value.
struct ProfileField: Codable, Identifiable, Equatable {
    var id = UUID()
    var label = ""
    var value = ""
}

/// Your reusable details as plain editable rows; click the copy button to copy a value.
final class ProfileModule: NotchModule, ObservableObject {
    let id = "profile"
    let title = "Profile"
    let icon = "person.text.rectangle"

    private static let file = "profile.json"

    /// Saved on every edit.
    @Published var fields: [ProfileField] {
        didSet { LocalStore.save(fields, to: Self.file) }
    }

    init() {
        fields = LocalStore.load([ProfileField].self, from: Self.file) ?? []
    }

    func makeView() -> AnyView { AnyView(ProfileView(module: self)) }

    func addRow() { fields.append(ProfileField()) }

    func remove(_ field: ProfileField) { fields.removeAll { $0.id == field.id } }

    func copy(_ field: ProfileField) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(field.value, forType: .string)
    }
}
