import SwiftUI

struct MusicView: View {
    @ObservedObject var module: MusicModule

    var body: some View {
        if let snapshot = module.snapshot {
            nowPlaying(snapshot)
        } else if !module.denied.isEmpty {
            permissionPrompt
        } else {
            idle
        }
    }

    // MARK: Now playing

    private func nowPlaying(_ s: PlayerSnapshot) -> some View {
        HStack(spacing: 16) {
            artworkView
                .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 4) {
                Text(s.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(s.artist).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Text(module.activePlayer?.appName ?? "").font(.system(size: 10)).foregroundStyle(.tertiary)

                Spacer(minLength: 4)

                ProgressView(value: min(s.position, max(s.duration, 1)), total: max(s.duration, 1))
                    .progressViewStyle(.linear)
                    .tint(.white)
                HStack {
                    Text(format(s.position))
                    Spacer()
                    Text(format(s.duration))
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)

                HStack(spacing: 26) {
                    Spacer()
                    control("backward.fill", size: 16) { module.previous() }
                    control(s.isPlaying ? "pause.fill" : "play.fill", size: 22) { module.togglePlayPause() }
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
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: Empty states

    /// Shown when macOS blocked the Automation permission for a player.
    private var permissionPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield").font(.system(size: 24)).foregroundStyle(.secondary)
            Text("NotchHub needs permission to control \(module.denied.map(\.appName).sorted().joined(separator: " / ")).")
                .font(.system(size: 12)).multilineTextAlignment(.center)
            Text("Enable it under Privacy & Security › Automation.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Button("Open Automation settings") { PermissionHelper.openAutomationSettings() }
                .controlSize(.small)
        }
    }

    private var idle: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list").font(.system(size: 26)).foregroundStyle(.secondary)
            Text("Nothing playing").font(.system(size: 13, weight: .medium))
            HStack {
                ForEach(MusicPlayer.allCases, id: \.appName) { player in
                    Button("Open \(player.appName)") { module.launch(player) }.controlSize(.small)
                }
            }
        }
    }
}
