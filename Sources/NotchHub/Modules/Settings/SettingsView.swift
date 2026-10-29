import SwiftUI

struct SettingsView: View {
    let module: SettingsModule
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 22) {
                modulesColumn.frame(width: 190)
                optionsColumn.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 6)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Modules

    private var modulesColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Tabs")
            ForEach(module.allModules().filter { !$0.alwaysEnabled }, id: \.id) { m in
                Button { settings.setEnabled(m.id, !settings.isEnabled(m.id)) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: m.icon).frame(width: 18)
                        Text(m.title).font(.system(size: 12))
                        Spacer()
                        Image(systemName: settings.isEnabled(m.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(settings.isEnabled(m.id) ? Color.green : Color.white.opacity(0.3))
                    }
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.07)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Options

    private var optionsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            option("Open notch") {
                segmented(ExpandMode.allCases, selection: $settings.expandMode) { $0 == .hover ? "Hover" : "Click" }
            }
            option("Tab icons") {
                segmented(TabBarPosition.allCases, selection: $settings.tabBarPosition) { $0.label }
            }
            option("Icon size") {
                segmented(AppSettings.iconSizes.map(\.value), selection: $settings.iconSize) { v in
                    AppSettings.iconSizes.first { $0.value == v }?.label ?? ""
                }
            }
            option("Zoom on hover") {
                segmented(AppSettings.hoverZooms.map(\.value), selection: $settings.hoverZoom) { v in
                    AppSettings.hoverZooms.first { $0.value == v }?.label ?? ""
                }
            }
            HStack(spacing: 10) {
                Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                        set: { settings.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch).controlSize(.small).font(.system(size: 12))
                Spacer()
                Button("Automation…") { PermissionHelper.openAutomationSettings() }
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
    }

    private func option<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).frame(width: 96, alignment: .leading)
            content()
        }
    }

    /// Compact segmented control for any Equatable choice.
    private func segmented<T: Equatable>(_ options: [T], selection: Binding<T>, label: @escaping (T) -> String) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, value in
                Button { selection.wrappedValue = value } label: {
                    Text(label(value)).font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity).frame(height: 22)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(selection.wrappedValue == value ? 0.22 : 0.07)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
