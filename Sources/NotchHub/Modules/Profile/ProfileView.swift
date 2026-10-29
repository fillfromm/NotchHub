import SwiftUI

struct ProfileView: View {
    @ObservedObject var module: ProfileModule
    @State private var query = ""
    @State private var filter: ProfileKind?
    @State private var adding = false
    @State private var newLabel = ""
    @State private var newValue = ""
    @State private var newKind: ProfileKind?
    @State private var copiedID: UUID?

    private var visible: [ProfileField] {
        module.fields.filter { field in
            (filter == nil || field.kind == filter) &&
            (query.isEmpty || field.label.localizedCaseInsensitiveContains(query) || field.value.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search", text: $query).textFieldStyle(.plain)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 8).frame(height: 24).frame(maxWidth: 170)
                .background(Capsule().fill(Color.white.opacity(0.1)))

                chip(nil, "All")
                ForEach(ProfileKind.allCases) { chip($0, $0.label) }
                Spacer()
                Button { adding.toggle() } label: {
                    Label(adding ? "Cancel" : "Add", systemImage: adding ? "xmark" : "plus").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if adding { addForm }
            list
        }
    }

    private func chip(_ kind: ProfileKind?, _ title: String) -> some View {
        Button { filter = kind } label: {
            Text(title).font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 9).frame(height: 24)
                .background(Capsule().fill(Color.white.opacity(filter == kind ? 0.22 : 0.07)))
                .foregroundStyle(filter == kind ? Color.white : Color.white.opacity(0.6))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var addForm: some View {
        HStack(spacing: 6) {
            TextField("Name", text: $newLabel).frame(width: 100)
            TextField("Value, e.g. you@mail.com", text: $newValue).onSubmit(save)
            Picker("", selection: $newKind) {
                Text("Auto").tag(ProfileKind?.none)
                ForEach(ProfileKind.allCases) { Text($0.label).tag(ProfileKind?.some($0)) }
            }
            .labelsHidden().frame(width: 80)
            Button("Save", action: save)
                .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .textFieldStyle(.roundedBorder).controlSize(.small)
        .padding(.horizontal, 4)
    }

    private func save() {
        module.add(label: newLabel, value: newValue, kind: newKind)
        newLabel = ""; newValue = ""; newKind = nil; adding = false
    }

    @ViewBuilder
    private var list: some View {
        if visible.isEmpty {
            Spacer()
            Text(module.fields.isEmpty ? "Add your email, phone and profile links once,\nthen copy them with one click."
                                       : "Nothing matches.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 4) { ForEach(visible) { row($0) } }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func row(_ field: ProfileField) -> some View {
        HStack(spacing: 10) {
            Image(systemName: field.kind.symbol).foregroundStyle(.secondary).frame(width: 18)
            Text(field.label).font(.system(size: 12, weight: .semibold)).frame(width: 96, alignment: .leading).lineLimit(1)
            Text(field.value).font(.system(size: 12)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if copiedID == field.id {
                Label("Copied", systemImage: "checkmark").font(.system(size: 10)).foregroundStyle(.green)
            }
            Button { module.remove(field) } label: {
                Image(systemName: "xmark").foregroundStyle(.white.opacity(0.3))
                    .frame(width: 22, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Delete")
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
        .contentShape(Rectangle())
        .onTapGesture {
            module.copy(field)
            copiedID = field.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if copiedID == field.id { copiedID = nil } }
        }
    }
}
