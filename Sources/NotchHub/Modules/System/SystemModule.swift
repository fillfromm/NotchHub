import Foundation
import IOKit.ps
import SwiftUI

/// Battery, CPU, memory and disk. Sampling runs only while the tab is visible
/// (battery is also checked occasionally so a low-battery warning can show when collapsed).
final class SystemModule: NotchModule, ObservableObject {
    let id = "system"
    let title = "System"
    let icon = "cpu"

    @Published private(set) var batteryLevel: Int?      // nil on Macs without a battery
    @Published private(set) var isCharging = false
    @Published private(set) var cpu: Double = 0         // 0...1
    @Published private(set) var memoryUsed: Double = 0  // 0...1
    @Published private(set) var memoryText = ""
    @Published private(set) var diskUsed: Double = 0    // 0...1
    @Published private(set) var diskText = ""

    private var fastTimer: Timer?
    private var slowTimer: Timer?
    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    init() {
        readBattery()
        slowTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.readBattery() }
        }
    }

    deinit { fastTimer?.invalidate(); slowTimer?.invalidate() }

    var compactInfo: CompactInfo? {
        guard let level = batteryLevel, level <= 15, !isCharging else { return nil }
        return CompactInfo(icon: "battery.25", text: "\(level)%", priority: 5)
    }

    func makeView() -> AnyView { AnyView(SystemView(module: self)) }

    // MARK: Sampling lifecycle (called by the view)

    func startSampling() {
        sample()
        fastTimer?.invalidate()
        fastTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
    }

    func stopSampling() {
        fastTimer?.invalidate()
        fastTimer = nil
        previousTicks = nil
    }

    private func sample() {
        readBattery()
        readCPU()
        readMemory()
        readDisk()
    }

    // MARK: Readers

    private func readBattery() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let capacity = desc[kIOPSCurrentCapacityKey] as? Int else { continue }
            batteryLevel = capacity
            isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
            return
        }
        batteryLevel = nil
    }

    /// CPU load = share of non-idle ticks since the previous sample.
    private func readCPU() {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return }
        let ticks = (user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
        defer { previousTicks = ticks }
        guard let prev = previousTicks else { return }

        let busy = Double(ticks.user &- prev.user) + Double(ticks.system &- prev.system) + Double(ticks.nice &- prev.nice)
        let idle = Double(ticks.idle &- prev.idle)
        let total = busy + idle
        if total > 0 { cpu = busy / total }
    }

    private func readMemory() {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64()
        let status = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return }
        let page = UInt64(sysconf(_SC_PAGESIZE))
        let used = (UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        let total = ProcessInfo.processInfo.physicalMemory
        memoryUsed = min(1, Double(used) / Double(total))
        memoryText = "\(Self.gigabytes(used)) of \(Self.gigabytes(total))"
    }

    private func readDisk() {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage else { return }
        diskUsed = min(1, max(0, 1 - Double(free) / Double(total)))
        diskText = "\(Self.gigabytes(UInt64(free))) free"
    }

    private static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }
}

struct SystemView: View {
    @ObservedObject var module: SystemModule

    var body: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        LazyVGrid(columns: columns, spacing: 10) {
            if let level = module.batteryLevel {
                tile(module.isCharging ? "Battery · charging" : "Battery", fraction: Double(level) / 100,
                     value: "\(level)%", detail: nil, goodWhenHigh: true)
            }
            tile("CPU", fraction: module.cpu, value: "\(Int(module.cpu * 100))%", detail: nil)
            tile("Memory", fraction: module.memoryUsed, value: "\(Int(module.memoryUsed * 100))%", detail: module.memoryText)
            tile("Disk", fraction: module.diskUsed, value: "\(Int(module.diskUsed * 100))%", detail: module.diskText)
        }
        .padding(.horizontal, 6)
        .onAppear { module.startSampling() }
        .onDisappear { module.stopSampling() }
    }

    private func tile(_ title: String, fraction: Double, value: String, detail: String?, goodWhenHigh: Bool = false) -> some View {
        let bad = goodWhenHigh ? fraction < 0.2 : fraction > 0.85
        let warn = goodWhenHigh ? fraction < 0.4 : fraction > 0.65
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
            }
            ProgressView(value: fraction).tint(bad ? .red : (warn ? .orange : .green))
            Text(detail ?? " ").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
    }
}
