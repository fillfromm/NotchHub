import AppKit
import AudioToolbox
import CoreAudio
import SwiftUI

/// One audio output (speakers, headphones, monitor, AirPods…).
struct OutputDevice: Identifiable, Equatable {
    var id: AudioObjectID
    var name: String
    /// nil when the device has no software volume (some HDMI / DisplayPort outputs).
    var volume: Float?
    var muted: Bool
    var isDefault: Bool

    /// SF Symbol guessed from the device name.
    var symbol: String {
        let lower = name.lowercased()
        if lower.contains("airpods") || lower.contains("headphone") || lower.contains("buds") || lower.contains("headset") {
            return "headphones"
        }
        if lower.contains("display") || lower.contains("hdmi") || lower.contains("monitor") { return "display" }
        if lower.contains("bluetooth") || lower.contains("speaker") && !lower.contains("macbook") { return "hifispeaker" }
        return "speaker.wave.2"
    }
}

/// Output volume per device, quick output switching, and the Music app's own volume.
///
/// macOS has no public API for per-app volume (that needs a virtual audio driver),
/// so only apps with their own volume control (Music) are offered.
/// Sampling runs only while the tab is visible.
final class VolumeModule: NotchModule, ObservableObject {
    let id = "volume"
    let title = "Volume"
    let icon = "speaker.wave.2"

    @Published private(set) var devices: [OutputDevice] = []
    /// Music app volume 0...100; nil when Music isn't running.
    @Published private(set) var musicVolume: Double?

    private var timer: Timer?

    func makeView() -> AnyView { AnyView(VolumeView(module: self)) }

    // MARK: Sampling lifecycle (called by the view)

    func startSampling() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stopSampling() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let list = Self.readDevices()
        if list != devices { devices = list }
        refreshMusicVolume()
    }

    // MARK: Actions

    func setVolume(_ device: OutputDevice, to value: Float) {
        var v = max(0, min(1, value))
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        AudioObjectSetPropertyData(device.id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        if let index = devices.firstIndex(where: { $0.id == device.id }) { devices[index].volume = v }
    }

    func toggleMute(_ device: OutputDevice) {
        var muted: UInt32 = device.muted ? 0 : 1
        var address = Self.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        AudioObjectSetPropertyData(device.id, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muted)
        if let index = devices.firstIndex(where: { $0.id == device.id }) { devices[index].muted = muted != 0 }
    }

    /// Makes `device` the system output.
    func makeDefault(_ device: OutputDevice) {
        var id = device.id
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
            var address = Self.address(selector)
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                       UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        }
        refresh()
    }

    // MARK: Music app volume (AppleScript)

    private func refreshMusicVolume() {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else {
            musicVolume = nil
            return
        }
        AppleScriptRunner.shared.run("tell application \"Music\" to return sound volume") { [weak self] result in
            if case .success(let descriptor) = result { self?.musicVolume = Double(descriptor.int32Value) }
        }
    }

    func setMusicVolume(_ value: Double) {
        musicVolume = value
        AppleScriptRunner.shared.run("tell application \"Music\" to set sound volume to \(Int(value))") { _ in }
    }

    // MARK: CoreAudio helpers

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func readDevices() -> [OutputDevice] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var devicesAddress = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &devicesAddress, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &devicesAddress, 0, nil, &size, &ids) == noErr else { return [] }

        var defaultID = AudioDeviceID(0)
        var defaultAddress = address(kAudioHardwarePropertyDefaultOutputDevice)
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(system, &defaultAddress, 0, nil, &defaultSize, &defaultID)

        return ids.compactMap { id in
            guard hasOutput(id) else { return nil }
            return OutputDevice(id: id, name: name(of: id), volume: volume(of: id), muted: isMuted(id), isDefault: id == defaultID)
        }
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var address = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, buffer) == noErr else { return false }
        let list = UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self))
        return list.contains { $0.mNumberChannels > 0 }
    }

    private static func name(of id: AudioDeviceID) -> String {
        var address = address(kAudioObjectPropertyName)
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &cfName) == noErr, let cfName else { return "Unknown device" }
        return cfName.takeRetainedValue() as String
    }

    private static func volume(of id: AudioDeviceID) -> Float? {
        var address = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func isMuted(_ id: AudioDeviceID) -> Bool {
        var address = address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        guard AudioObjectHasProperty(id, &address) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr && value != 0
    }
}
