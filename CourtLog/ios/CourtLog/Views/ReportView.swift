import SwiftUI

struct ReportView: View {
    let session: Session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(session.createdAt.formatted(date: .long, time: .shortened))
                    .font(.title2.bold())

                HStack {
                    StatCard(title: "时长", value: formatDuration(session.durationSec), icon: "clock")
                    if let hr = session.avgHeartRate {
                        StatCard(title: "平均心率", value: "\(Int(hr))", icon: "heart.fill")
                    }
                }

                Text("落点热力图")
                    .font(.headline)

                HeatmapView(grid: mockHeatmap())
                    .frame(height: 280)
                    .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

                HStack {
                    StatCard(title: "最高球速", value: "— km/h", icon: "speedometer")
                    StatCard(title: "平均球速", value: "— km/h", icon: "gauge.medium")
                }

                Text("分析完成后将显示真实数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("训练报告")
    }

    private func formatDuration(_ sec: Double) -> String {
        let m = Int(sec) / 60
        return "\(m) 分钟"
    }

    private func mockHeatmap() -> [[Double]] {
        // Placeholder until analysis JSON is loaded
        Array(repeating: Array(repeating: 0.0, count: 10), count: 20)
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
            let maxVal = grid.flatMap { $0 }.max() ?? 1

            for (r, row) in grid.enumerated() {
                for (c, val) in row.enumerated() {
                    let intensity = maxVal > 0 ? val / maxVal : 0
                    let rect = CGRect(
                        x: CGFloat(c) * cellW,
                        y: CGFloat(r) * cellH,
                        width: cellW - 1,
                        height: cellH - 1
                    )
                    context.fill(
                        Path(rect),
                        with: .color(.red.opacity(0.15 + intensity * 0.75))
                    )
                }
            }

            // Court outline
            context.stroke(
                Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                with: .color(.white),
                lineWidth: 2
            )
        }
    }
}
