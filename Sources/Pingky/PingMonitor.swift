import Foundation
import Combine

/// Pings a host once per second, keeping a rolling buffer of the most recent
/// results. Oldest sample is at index 0, newest is appended at the end.
@MainActor
final class PingMonitor: ObservableObject {

    /// Total cells in the heatmap: 100 wide x 30 high.
    static let capacity = 3000

    let host: String

    @Published private(set) var samples: [Sample] = []

    private var timer: Timer?

    init(host: String = "8.8.8.8") {
        self.host = host
        samples.reserveCapacity(Self.capacity)
    }

    func start() {
        guard timer == nil else { return }
        // Fire one immediately so the panel isn't blank on launch.
        tick()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let host = self.host
        // Run the ping off the main thread; deliver the result back on the main actor.
        Task.detached(priority: .utility) {
            let sample = Self.runPing(host: host)
            await MainActor.run { [weak self] in
                self?.append(sample)
            }
        }
    }

    private func append(_ sample: Sample) {
        samples.append(sample)
        if samples.count > Self.capacity {
            samples.removeFirst(samples.count - Self.capacity)
        }
    }

    // MARK: - Ping

    /// Runs `/sbin/ping -c 1 -W 1000 <host>` and parses the round-trip time.
    /// `/sbin/ping` is setuid root on macOS, so this needs no elevated privileges.
    nonisolated private static func runPing(host: String) -> Sample {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-W", "1000", "-t", "2", host]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return .dropped
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8),
              let ms = parseTime(from: output) else {
            return .dropped
        }
        return .latency(ms)
    }

    /// Extracts the milliseconds from a `time=12.345 ms` token in ping output.
    nonisolated private static func parseTime(from output: String) -> Double? {
        guard let range = output.range(of: "time=") else { return nil }
        let rest = output[range.upperBound...]
        let numberChars = rest.prefix { $0.isNumber || $0 == "." }
        return Double(numberChars)
    }

    // MARK: - Derived stats

    var current: Sample? { samples.last }

    var latencies: [Double] { samples.compactMap { $0.ms } }

    var minLatency: Double? { latencies.min() }
    var maxLatency: Double? { latencies.max() }

    var avgLatency: Double? {
        let values = latencies
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Percentile (0...100) of round-trip times (ms) over successful pings,
    /// using linear interpolation between ranks.
    /// `window` limits to the most recent N samples; nil uses the whole buffer.
    func percentile(_ p: Double, window: Int? = nil) -> Double? {
        let slice = window.map { samples.suffix($0) } ?? samples[...]
        let values = slice.compactMap { $0.ms }.sorted()
        guard !values.isEmpty else { return nil }
        guard values.count > 1 else { return values[0] }
        let rank = (p / 100) * Double(values.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        let weight = rank - Double(lower)
        return values[lower] + (values[upper] - values[lower]) * weight
    }

    /// p50/p90/p99 over the last 5 minutes (300 samples at 1 Hz).
    var percentiles5m: (p50: Double?, p90: Double?, p99: Double?) {
        (percentile(50, window: 300), percentile(90, window: 300), percentile(99, window: 300))
    }

    /// p50/p90/p99 over the entire buffer.
    var percentilesAll: (p50: Double?, p90: Double?, p99: Double?) {
        (percentile(50), percentile(90), percentile(99))
    }

    /// Packet loss as a fraction (0...1) over the current buffer.
    var lossFraction: Double {
        guard !samples.isEmpty else { return 0 }
        let dropped = samples.lazy.filter { $0 == .dropped }.count
        return Double(dropped) / Double(samples.count)
    }
}
