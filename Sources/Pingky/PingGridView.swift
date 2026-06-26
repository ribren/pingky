import SwiftUI

struct PingGridView: View {
    @EnvironmentObject var monitor: PingMonitor

    private let cols = 100
    private let rows = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            heatmap
        }
        .padding(10)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(monitor.host)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Spacer(minLength: 8)
                Text(currentText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text(lossText)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            percentileLine(label: "5m ", monitor.percentiles5m)
            percentileLine(label: "all", monitor.percentilesAll)
        }
        .foregroundStyle(.primary)
    }

    private func percentileLine(label: String, _ p: (p50: Double?, p90: Double?, p99: Double?)) -> some View {
        HStack(spacing: 10) {
            Text(label).foregroundStyle(.tertiary)
            Text("p50 \(msText(p.p50))")
            Text("p90 \(msText(p.p90))")
            Text("p99 \(msText(p.p99))")
            Spacer(minLength: 0)
        }
        .font(.system(size: 10, weight: .regular, design: .monospaced))
        .foregroundStyle(.secondary)
    }

    private func msText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f ms", value)
    }

    private var statusColor: Color {
        guard let current = monitor.current else { return LatencyColor.droppedColor }
        return LatencyColor.color(for: current)
    }

    private var currentText: String {
        switch monitor.current {
        case .latency(let ms): return String(format: "%.0f ms", ms)
        case .dropped:         return "drop"
        case .none:            return "—"
        }
    }

    private var lossText: String {
        String(format: "%.0f%% loss", monitor.lossFraction * 100)
    }

    // MARK: - Heatmap

    private var heatmap: some View {
        Canvas { context, size in
            let samples = monitor.samples
            guard !samples.isEmpty else { return }

            let cellW = size.width / CGFloat(cols)
            let cellH = size.height / CGFloat(rows)
            let n = samples.count

            for (i, sample) in samples.enumerated() {
                // Newest sample (age 0) is pinned to the top-right corner.
                // Fill proceeds top -> bottom down a column, then right -> left.
                let age = (n - 1) - i
                let col = (cols - 1) - (age / rows)
                let row = age % rows
                guard col >= 0 else { break }

                // Flush cells, no borders or gaps. Round outward slightly so
                // adjacent boxes have no seam from sub-pixel rounding.
                let x0 = (CGFloat(col) * cellW).rounded(.down)
                let y0 = (CGFloat(row) * cellH).rounded(.down)
                let x1 = (CGFloat(col + 1) * cellW).rounded(.up)
                let y1 = (CGFloat(row + 1) * cellH).rounded(.up)
                let rect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)

                let color = sample == .dropped
                    ? LatencyColor.droppedColor
                    : LatencyColor.color(for: sample)
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(minWidth: 300, minHeight: 90)
    }
}
