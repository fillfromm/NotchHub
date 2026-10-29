import SwiftUI

struct VolumeView: View {
    @ObservedObject var module: VolumeModule

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(module.devices) { deviceRow($0) }

                if let music = module.musicVolume {
                    HStack(spacing: 10) {
                        Image(systemName: "music.note").frame(width: 22)
                        Text("Music app").font(.system(size: 12, weight: .medium)).frame(width: 130, alignment: .leading)
                        Slider(value: Binding(get: { music }, set: { module.setMusicVolume($0) }), in: 0...100)
                            .controlSize(.small).tint(.white)
                        Text("\(Int(music))").font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                }

                Text("Per-app volume for other apps isn't available in macOS without an extra audio driver.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 2)
            }
            .padding(.horizontal, 6)
        }
        .scrollIndicators(.hidden)
        .onAppear { module.startSampling() }
        .onDisappear { module.stopSampling() }
    }

    private func deviceRow(_ device: OutputDevice) -> some View {
        HStack(spacing: 10) {
            // The active output is highlighted; click a device to switch to it.
            Button { module.makeDefault(device) } label: {
                HStack(spacing: 8) {
                    Image(systemName: device.symbol).frame(width: 22)
                    Text(device.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        .frame(width: 130, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(device.isDefault ? "Current output" : "Use this output")

            if let volume = device.volume {
                Slider(value: Binding(get: { Double(volume) }, set: { module.setVolume(device, to: Float($0)) }), in: 0...1)
                    .controlSize(.small).tint(.white)
                    .opacity(device.muted ? 0.4 : 1)
                Button { module.toggleMute(device) } label: {
                    Image(systemName: device.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(device.muted ? Color.orange : Color.white.opacity(0.7))
                        .frame(width: 26, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text("Volume is set on the device itself")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(device.isDefault ? 0.16 : 0.06)))
        .overlay(alignment: .leading) {
            if device.isDefault { Capsule().fill(Color.green).frame(width: 3, height: 18).offset(x: 2) }
        }
    }
}
