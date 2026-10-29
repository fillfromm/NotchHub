import AppKit
import SwiftUI

/// iPhone-style wheel: shows the neighbouring values faded above and below and
/// wraps around. Change it with the scroll wheel / trackpad, or by dragging up and down.
struct WheelPicker: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var rowHeight: CGFloat = 26

    private var count: Int { range.count }

    private func wrapped(_ v: Int) -> Int {
        let offset = (v - range.lowerBound) % count
        return range.lowerBound + (offset < 0 ? offset + count : offset)
    }

    var body: some View {
        ZStack {
            // Highlight band behind the selected row.
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.14))
                .frame(height: rowHeight)

            VStack(spacing: 0) {
                ForEach(-2...2, id: \.self) { offset in
                    Text(String(format: "%02d", wrapped(value + offset)))
                        .font(.system(size: offset == 0 ? 22 : 17, weight: offset == 0 ? .semibold : .regular, design: .rounded).monospacedDigit())
                        .opacity(offset == 0 ? 1 : (abs(offset) == 1 ? 0.4 : 0.15))
                        .frame(height: rowHeight)
                }
            }
            .animation(nil, value: value)

            WheelInput(rowHeight: rowHeight) { step in value = wrapped(value + step) }
        }
        .frame(width: 58, height: rowHeight * 5)
        .clipped()
    }
}

/// Transparent AppKit view that turns scrolling and dragging into whole steps.
/// (SwiftUI has no scroll-wheel event on macOS.)
private struct WheelInput: NSViewRepresentable {
    let rowHeight: CGFloat
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> InputView {
        let view = InputView()
        view.rowHeight = rowHeight
        view.onStep = onStep
        return view
    }

    func updateNSView(_ view: InputView, context: Context) {
        view.rowHeight = rowHeight
        view.onStep = onStep
    }

    final class InputView: NSView {
        var rowHeight: CGFloat = 26
        var onStep: (Int) -> Void = { _ in }
        /// Overall wheel speed; lower = slower, easier to land on an exact value.
        private let sensitivity: CGFloat = 0.9
        private var scrollAccumulator: CGFloat = 0
        private var dragAccumulator: CGFloat = 0
        private var lastDragY: CGFloat = 0

        // The notch panel is non-activating: accept the very first click.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func scrollWheel(with event: NSEvent) {
            // Trackpads send many small deltas, mice a few big ones.
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 14 : event.scrollingDeltaY
            scrollAccumulator += delta * sensitivity
            while scrollAccumulator <= -1 { onStep(1); scrollAccumulator += 1 }
            while scrollAccumulator >= 1 { onStep(-1); scrollAccumulator -= 1 }
        }

        override func mouseDown(with event: NSEvent) {
            lastDragY = event.locationInWindow.y
            dragAccumulator = 0
        }

        override func mouseDragged(with event: NSEvent) {
            // Dragging up moves the wheel up, so later values come into view.
            dragAccumulator += (event.locationInWindow.y - lastDragY) * sensitivity
            lastDragY = event.locationInWindow.y
            while dragAccumulator >= rowHeight { onStep(1); dragAccumulator -= rowHeight }
            while dragAccumulator <= -rowHeight { onStep(-1); dragAccumulator += rowHeight }
        }
    }
}
