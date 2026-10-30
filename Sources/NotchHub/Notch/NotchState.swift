import SwiftUI

/// Observable UI state shared between the controller (AppKit) and the SwiftUI views.
final class NotchState: ObservableObject {
    @Published var isExpanded = false
    @Published var geometry: NotchGeometry
    @Published var compact: CompactInfo?

    /// Size of the expanded notch (content area below the notch row is fixed-height).
    static let expandedWidth: CGFloat = 660
    /// The side tab bar needs more room for its column of icons.
    var contentHeight: CGFloat {
        contentHeightOverride ?? (AppSettings.shared.tabBarPosition == .side ? 224 : 190)
    }
    /// Set by the controller from the selected module's `preferredContentHeight`.
    @Published var contentHeightOverride: CGFloat?

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    var collapsedSize: CGSize {
        CGSize(width: geometry.collapsedWidth(showingInfo: compact != nil), height: geometry.height)
    }

    var expandedSize: CGSize {
        CGSize(width: Self.expandedWidth, height: geometry.height + contentHeight)
    }

    /// Current visible size.
    var currentSize: CGSize { isExpanded ? expandedSize : collapsedSize }
}
