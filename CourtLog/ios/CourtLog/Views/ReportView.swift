import SwiftUI

struct ReportView: View {
    let session: Session

  private var analysis: AnalysisResult? {
        guard let data = session.analysisJSON else { return nil }
        return try? JSONDecoder().decode(AnalysisResult.self, from: data)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(session.createdAt.formatted(date: .long, time: .shortened))
                    .font(.title2.bold())

                HStack {
                    StatCard(title: "时长", value: formatDuration(session.durationSec), icon: "clock")
                    if let hr = session.avgHeartRate {
                        StatCard(title: "平均心率", value: "\(Int(hr)) bpm", icon: "heart.fill")
                    }
                }

                Text("落点热力图")
                    .font(.headline)

                HeatmapView(grid: heatmapGrid())
                    .frame(height: 280)
                    .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

                HStack {
                    StatCard(
                        title: "最高球速",
                        value: speedText(analysis?.bounces.map(\.speedKmh).max()),
                        icon: "speedometer"
                    )
                    StatCard(
                        title: "平均球速",
                        value: avgSpeedText(),
                        icon: "gauge.medium"
                    )
                }

                if let analysis, !analysis.bounces.isEmpty {
                    Text("落点记录 \(analysis.bounces.count) 次")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if analysis == nil {
                    Text("尚无分析数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("训练报告")
    }

    private func formatDuration(_ sec: Double) -> String {
        let m = Int(sec) / 60
        return "\(m) 分钟"
    }

    private func heatmapGrid() -> [[Double]] {
        guard let counts = analysis?.heatmap.counts else {
            return Array(repeating: Array(repeating: 0.0, count: 10), count: 20)
        }
        let maxVal = Double(counts.flatMap { $0 }.max() ?? 1)
        return counts.map { row in row.map { Double($0) / maxVal } }
    }

    private func speedText(_ value: Double?) -> String {
        guard let value else { return "— km/h" }
        return String(format: "%.0f km/h", value)
    }

    private func avgSpeedText() -> String {
        let speeds = analysis?.bounces.map(\.speedKmh) ?? []
        guard !speeds.isEmpty else { return "— km/h" }
        let avg = speeds.reduce(0, +) / Double(speeds.count)
        return String(format: "%.0f km/h", avg)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct HeatmapView: View {
    let grid: [[Double]]

    var body: some View {
        Canvas { context, size in
            let rows = grid.count
            let cols = grid.first?.count ?? 1
            let cellW = size.width / CGFloat(cols)
            let cellH = size.height / CGFloat(rows)

            for (r, row) in grid.enumerated() {
                for (c, val) in row.enumerated() {
                    let rect = CGRect(
                        x: CGFloat(c) * cellW,
                        y: CGFloat(r) * cellH,
                        width: cellW - 1,
                        height: cellH - 1
                    )
                    context.fill(
                        Path(rect),
                        with: .color(.red.opacity(0.15 + val * 0.75))
                    )
                }
            }

            context.stroke(
                Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                with: .color(.white),
                lineWidth: 2
            )
        }
    }
}
