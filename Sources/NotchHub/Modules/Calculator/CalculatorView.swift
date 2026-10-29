import SwiftUI

struct CalculatorView: View {
    @ObservedObject var module: CalculatorModule
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("2 * (3 + 4) ^ 2, sqrt(9), pi…", text: $module.input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, design: .monospaced))
                    .focused($focused)
                    .onSubmit { module.submit() }
                    .onChange(of: module.input) { _, _ in module.updatePreview() }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))

                Text(module.preview)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(module.previewIsError ? Color.red : Color.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 20)

                Text("Return to save · + − × ÷ % ^ ( ) · sin cos sqrt ln log")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .frame(width: 270)

            VStack(spacing: 4) {
                HStack {
                    Text("History").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { module.clearHistory() }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                        .disabled(module.history.isEmpty)
                }
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(module.history) { entry in
                            Button { module.use(entry) } label: {
                                HStack {
                                    Text(entry.expression).lineLimit(1).foregroundStyle(.secondary)
                                    Spacer(minLength: 4)
                                    Text(entry.result).lineLimit(1)
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
    }
}
