import SwiftUI

struct MusicView: View {
    @ObservedObject var module: MusicModule
    @State private var dragPosition: Double?

    var body: some View {
        if module.permissionDenied {
            permissionPrompt
        } else if let track = module.display {
            nowPlaying(track)
        } else {
            idle
        }
    }

    // MARK: Now playing

    private func nowPlaying(_ s: TrackSnapshot) -> some View {
        HStack(spacing: 16) {
            artworkView
                .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 4) {
                Text(s.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(s.artist).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Text(module.live == nil ? "Last played · Apple Music" : "Apple Music")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)

                Spacer(minLength: 4)

                // While dragging, show the dragged value; the 1s poll must not fight the thumb.
                Slider(
                    value: Binding(
                        get: { dragPosition ?? min(s.position, max(s.duration, 1)) },
                        set: { dragPosition = $0 }
                    ),
                    in: 0...max(s.duration, 1)
                ) { editing in
                    if !editing, let target = dragPosition {
                        module.seek(to: target)
                        dragPosition = nil
                    }
                }
                .controlSize(.small)
                .tint(.white)
                .disabled(module.live == nil)
                HStack {
                    Text(format(dragPosition ?? s.position))
                    Spacer()
                    Text(format(s.duration))
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)

                HStack(spacing: 26) {
                    Spacer()
                    control("backward.fill", size: 16) { module.previous() }
                    control(module.isPlaying ? "pause.fill" : "play.fill", size: 22) { module.togglePlayPause() }
                    control("forward.fill", size: 16) { module.next() }
                    Spacer()
                }
            }
            .frame(maxHeight: 112)
        }
        .padding(.horizontal, 6)
    }

    private var artworkView: some View {
        Group {
            if let image = module.artwork {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note").font(.system(size: 30)).foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func control(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size))
                .frame(width: 40, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: Empty states

    /// Shown when macOS blocked the Automation permission for Music.
    private var permissionPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield").font(.system(size: 24)).foregroundStyle(.secondary)
            Text("NotchHub needs permission to control Music.")
                .font(.system(size: 12)).multilineTextAlignment(.center)
            Text("Enable NotchHub under Privacy & Security › Automation.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Button("Open Automation settings") { PermissionHelper.openAutomationSettings() }
                .controlSize(.small)
        }
    }

    private var idle: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list").font(.system(size: 26)).foregroundStyle(.secondary)
            Text("Nothing played yet").font(.system(size: 13, weight: .medium))
            Button("Open Music") { module.openApp() }.controlSize(.small)
        }
    }
}
