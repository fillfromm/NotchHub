import SwiftUI

/// Root SwiftUI view: draws the black notch shape and swaps between
/// the collapsed (compact info) and expanded (tabs) content.
struct NotchRootView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var registry: ModuleRegistry

    private let spring = Animation.spring(response: 0.4, dampingFraction: 0.82)

    var body: some View {
        let size = state.currentSize
        ZStack(alignment: .top) {
            NotchShape(topRadius: state.isExpanded ? 14 : (state.geometry.hasNotch ? 0 : 0),
                       bottomRadius: state.isExpanded ? 26 : (state.geometry.hasNotch ? 10 : 12))
                .fill(Color.black)

            if state.isExpanded {
                ExpandedView(state: state, registry: registry)
                    .padding(.horizontal, 14)
                    .transition(.opacity)
            } else {
                CollapsedView(state: state)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: state.isExpanded)
        .animation(spring, value: state.contentHeightOverride)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}

/// Collapsed notch: icon on the left wing, short text on the right wing.
struct CollapsedView: View {
    @ObservedObject var state: NotchState

    var body: some View {
        if let info = state.compact {
            HStack(spacing: 0) {
                Image(systemName: info.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: state.geometry.hasNotch ? NotchGeometry.wingWidth : nil)
                Spacer(minLength: state.geometry.hasNotch ? state.geometry.notchWidth : 8)
                Text(info.text)
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: state.geometry.hasNotch ? NotchGeometry.wingWidth - 8 : nil, alignment: .leading)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, state.geometry.hasNotch ? 0 : 14)
            .frame(height: state.geometry.height)
        }
    }
}

/// Expanded notch: icon bar (around the physical notch, or in a column on the left),
/// module content next to / below it.
struct ExpandedView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var registry: ModuleRegistry
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Group {
            if settings.tabBarPosition == .side {
                HStack(spacing: 8) {
                    sideBar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: state.geometry.height) // row beside the physical notch
                        content
                    }
                }
            } else {
                VStack(spacing: 0) {
                    header.frame(height: state.geometry.height)
                    content
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var content: some View {
        Group {
            if let module = registry.selected {
                module.makeView()
                    .id(module.id)
                    .transition(.opacity)
            } else {
                Text("No modules enabled.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 14)
    }

    /// Icon bar, split into two halves so the physical notch sits between them.
    private var header: some View {
        let modules = registry.enabled
        let mid = (modules.count + 1) / 2
        let left = Array(modules[..<mid])
        let right = Array(modules[mid...])
        // Shrink the icons' hit areas if a wing is too narrow for them all.
        let wing: CGFloat = (NotchState.expandedWidth - 28 - state.geometry.notchWidth) / 2 - 20
        let perIcon: CGFloat = wing / CGFloat(max(left.count, 1)) - 2
        let width: CGFloat = min(CGFloat(settings.iconSize) * 2.1, perIcon)
        return HStack(spacing: 0) {
            HStack(spacing: 2) { ForEach(left, id: \.id) { tab($0, width: width) } }
                .padding(.leading, 12)
            Spacer(minLength: state.geometry.notchWidth)
            HStack(spacing: 2) { ForEach(right, id: \.id) { tab($0, width: width) } }
                .padding(.trailing, 12)
        }
    }

    /// Vertical icon column on the left edge; scrolls if there are more icons than room.
    private var sideBar: some View {
        ScrollView {
            VStack(spacing: 1) {
                ForEach(registry.enabled, id: \.id) { tab($0, width: settings.iconSize * 1.9, side: true) }
            }
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .frame(width: settings.iconSize * 1.9 + 4)
        .padding(.bottom, 8)
    }

    private func tab(_ module: NotchModule, width: CGFloat, side: Bool = false) -> some View {
        TabButton(module: module,
                  selected: registry.selected?.id == module.id,
                  size: settings.iconSize,
                  width: width,
                  zoom: settings.hoverZoom,
                  zoomAnchor: side ? .leading : .top) {
            withAnimation(.easeInOut(duration: 0.15)) { registry.select(module) }
        }
    }
}

/// One icon in the tab bar. Grows under the mouse and has a generous hit area,
/// so you don't have to aim precisely.
struct TabButton: View {
    let module: NotchModule
    let selected: Bool
    let size: Double
    let width: CGFloat
    let zoom: Double
    /// Zoom grows away from the screen edge: downwards in the top bar, rightwards in the side bar.
    let zoomAnchor: UnitPoint
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: module.icon)
                .font(.system(size: size, weight: .medium))
                .frame(width: width, height: size * 1.7)
                .background(Capsule().fill(selected ? Color.white.opacity(0.2) : (hovering ? Color.white.opacity(0.1) : .clear)))
                .foregroundStyle(selected || hovering ? Color.white : Color.white.opacity(0.55))
                .contentShape(Rectangle())
                .scaleEffect(hovering ? zoom : 1, anchor: zoomAnchor)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
        .zIndex(hovering ? 1 : 0)
        .help(module.title)
    }
}
