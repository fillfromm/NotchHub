import SwiftUI

struct TranslatorView: View {
    @ObservedObject var module: TranslatorModule
    @State private var copied = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                languagePicker($module.source)
                Button { module.swap() } label: {
                    Image(systemName: "arrow.left.arrow.right").frame(width: 30, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Swap languages")
                languagePicker($module.target)
                Spacer()
            }

            HStack(spacing: 10) {
                TextField("Type a word or phrase…", text: $module.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...4)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.05))
                    if module.failed {
                        Text("Couldn't translate. Check your internet connection.")
                            .font(.system(size: 12)).foregroundStyle(.orange).padding(10)
                    } else {
                        Text(module.output.isEmpty && module.busy ? "…" : module.output)
                            .font(.system(size: 14, weight: .medium))
                            .textSelection(.enabled)
                            .padding(10)
                            .opacity(module.busy ? 0.6 : 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        module.copyOutput()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain).foregroundStyle(copied ? Color.green : Color.white.opacity(0.6))
                    .padding(8)
                    .opacity(module.output.isEmpty ? 0 : 1)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private func languagePicker(_ selection: Binding<TranslatorLanguage>) -> some View {
        HStack(spacing: 2) {
            ForEach(TranslatorLanguage.allCases) { language in
                Button { selection.wrappedValue = language } label: {
                    Text(language.name).font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 9).frame(height: 24)
                        .background(Capsule().fill(Color.white.opacity(selection.wrappedValue == language ? 0.22 : 0.07)))
                        .foregroundStyle(selection.wrappedValue == language ? Color.white : Color.white.opacity(0.6))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
