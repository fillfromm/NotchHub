import SwiftUI

/// A short list of editable rows. Type a name and a value; the button copies the value.
struct ProfileView: View {
    @ObservedObject var module: ProfileModule
    @State private var copiedID: UUID?

    var body: some View {
        VStack(spacing: 6) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach($module.fields) { $field in row($field) }
                    if module.fields.isEmpty {
                        Text("Add a row, name it, and type a value.")
                            .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 20)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Button { module.addRow() } label: {
                Label("Add row", systemImage: "plus").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    private func row(_ field: Binding<ProfileField>) -> some View {
        HStack(spacing: 8) {
            TextField("Name", text: field.label)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 120)
            TextField("Value", text: field.value)
                .font(.system(size: 12))
            Button {
                module.copy(field.wrappedValue)
                copiedID = field.wrappedValue.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copiedID = nil }
            } label: {
                Image(systemName: copiedID == field.wrappedValue.id ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copiedID == field.wrappedValue.id ? Color.green : Color.white.opacity(0.7))
                    .frame(width: 24, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Copy")
            Button { module.remove(field.wrappedValue) } label: {
                Image(systemName: "xmark").foregroundStyle(.white.opacity(0.3))
                    .frame(width: 22, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Delete row")
        }
        .textFieldStyle(.plain)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
    }
}
