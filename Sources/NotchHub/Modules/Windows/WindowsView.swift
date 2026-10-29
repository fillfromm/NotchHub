import SwiftUI

/// Left: your open windows. Right: where to put the selected one.
struct WindowsView: View {
    @ObservedObject var module: WindowsModule

    var body: some View {
        Group {
            if module.trusted {
                HStack(alignment: .top, spacing: 14) {
                    windowList.frame(width: 250)
                    layoutGrid.frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 8) {
                    Text("Moving windows needs the Accessibility permission.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("Grant access…") { module.requestAccess() }.controlSize(.small)
                    Text("After enabling NotchHub there, reopen this tab.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 6)
        .onAppear { module.refresh() }
    }

    // MARK: Windows

    private var windowList: some View {
        VStack(spacing: 4) {
            HStack {
                Text("OPEN WINDOWS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { module.refresh() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 11)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Refresh")
            }
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(module.windows) { window in
                        let selected = module.selectedID == window.id
                        HStack(spacing: 8) {
                            if let icon = window.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(window.appName).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                                Text(window.title).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(selected ? 0.22 : 0.07)))
                        .contentShape(Rectangle())
                        .onTapGesture { module.selectedID = window.id }
                    }
                    if module.windows.isEmpty {
                        Text("No windows found").font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 12)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Layouts

    private var layoutGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PLACE IT").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if let applied = module.lastApplied {
                    Label(applied, systemImage: "checkmark").font(.system(size: 10)).foregroundStyle(.green)
                }
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                    ForEach(WindowLayout.all) { layout in
                        Button { module.apply(layout) } label: { preview(layout) }
                            .buttonStyle(.plain)
                            .help(layout.name)
                            .disabled(module.selected == nil)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Mini screen with the target area highlighted.
    private func preview(_ layout: WindowLayout) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.75))
                    .frame(width: max(geo.size.width * layout.w - 3, 4), height: max(geo.size.height * layout.h - 3, 4))
                    .offset(x: geo.size.width * layout.x + 1.5, y: geo.size.height * layout.y + 1.5)
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .contentShape(Rectangle())
    }
}
