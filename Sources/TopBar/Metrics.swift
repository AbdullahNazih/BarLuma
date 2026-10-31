import Foundation
import Darwin
import SystemConfiguration

struct CPUTicks {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    func utilization(since old: CPUTicks) -> Double? {
        let busy = UInt64(user &- old.user) + UInt64(system &- old.system) + UInt64(nice &- old.nice)
        let total = busy + UInt64(idle &- old.idle)
        guard total > 0 else { return nil }
        return Double(busy) / Double(total) * 100
    }
}

struct NetworkCounters {
    let interface: String
    let received: UInt64
    let sent: UInt64
    let timestamp: TimeInterval

    func rates(since old: NetworkCounters) -> (download: Double, upload: Double)? {
        let elapsed = timestamp - old.timestamp
        guard interface == old.interface, elapsed > 0, received >= old.received, sent >= old.sent else { return nil }
        return (Double(received - old.received) * 8 / elapsed / 1_000_000,
                Double(sent - old.sent) * 8 / elapsed / 1_000_000)
    }
}

struct MemoryReading {
    let used: UInt64
    let total: UInt64
    var percent: Double { total > 0 ? min(100, Double(used) / Double(total) * 100) : 0 }
}

enum SystemMetrics {
    private static let host = mach_host_self()
    private static let networkStore = SCDynamicStoreCreate(nil, "TopBar" as CFString, nil, nil)

    static func cpu() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    static func memory() -> MemoryReading? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // App memory (internal minus purgeable), wired memory, and physical compressor pages.
        let app = UInt64(info.internal_page_count) - min(UInt64(info.internal_page_count), UInt64(info.purgeable_count))
        let pages = app + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
        return MemoryReading(used: pages * UInt64(vm_kernel_page_size), total: ProcessInfo.processInfo.physicalMemory)
    }

    static func network() -> NetworkCounters? {
        // Read the physical primary route so VPN tunnels are not counted twice.
        var primary: String?
        if let store = networkStore {
            for family in ["IPv4", "IPv6"] {
                if let state = SCDynamicStoreCopyValue(store, "State:/Network/Global/\(family)" as CFString) as? [String: Any],
                   let name = state["PrimaryInterface"] as? String, !name.hasPrefix("utun") {
                    primary = name
                    break
                }
            }
        }
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        var candidates: [(String, UInt64, UInt64)] = []
        while let current = pointer {
            let entry = current.pointee
            pointer = entry.ifa_next
            guard let address = entry.ifa_addr, Int32(address.pointee.sa_family) == AF_LINK,
                  entry.ifa_flags & UInt32(IFF_UP) != 0,
                  entry.ifa_flags & UInt32(IFF_RUNNING) != 0 else { continue }
            let name = String(cString: entry.ifa_name)
            guard primary.map({ name == $0 }) ?? name.hasPrefix("en") else { continue }
            // The getifaddrs counters are only 32 bits on Darwin. Read IFMIB's
            // 64-bit counters so long-running and high-throughput sessions stay accurate.
            var stats = ifmibdata()
            var length = MemoryLayout<ifmibdata>.size
            var mib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, Int32(if_nametoindex(entry.ifa_name)), IFDATA_GENERAL]
            guard sysctl(&mib, u_int(mib.count), &stats, &length, nil, 0) == 0 else { continue }
            candidates.append((name, stats.ifmd_data.ifi_ibytes, stats.ifmd_data.ifi_obytes))
        }
        guard !candidates.isEmpty else { return nil }
        return NetworkCounters(interface: candidates.map(\.0).sorted().joined(separator: "+"),
                               received: candidates.reduce(0) { $0 + $1.1 },
                               sent: candidates.reduce(0) { $0 + $1.2 },
                               timestamp: ProcessInfo.processInfo.systemUptime)
    }
}
