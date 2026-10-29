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

/// Expanded notch: icon bar around the physical notch, module content below.
struct ExpandedView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var registry: ModuleRegistry

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: state.geometry.height)
            Group {
                if let module = registry.selected {
                    module.makeView()
                        .id(module.id)
                        .transition(.opacity)
                } else {
                    Text("No modules enabled.\nUse the menu bar icon to turn some on.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 14)
        }
        .foregroundStyle(.white)
    }

    /// Icon bar, split into two halves so the physical notch sits between them.
    private var header: some View {
        let modules = registry.enabled
        let mid = (modules.count + 1) / 2
        let left = Array(modules[..<mid])
        let right = Array(modules[mid...])
        return HStack(spacing: 0) {
            HStack(spacing: 2) { ForEach(left, id: \.id) { tab($0) } }
                .padding(.leading, 12)
            Spacer(minLength: state.geometry.notchWidth)
            HStack(spacing: 2) { ForEach(right, id: \.id) { tab($0) } }
                .padding(.trailing, 12)
        }
    }

    private func tab(_ module: NotchModule) -> some View {
        let selected = registry.selected?.id == module.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { registry.select(module) }
        } label: {
            Image(systemName: module.icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 24)
                .background(Capsule().fill(selected ? Color.white.opacity(0.18) : .clear))
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.55))
        }
        .buttonStyle(.plain)
        .help(module.title)
    }
}
