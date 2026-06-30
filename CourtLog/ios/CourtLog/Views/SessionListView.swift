import SwiftUI
import SwiftData

struct SessionListView: View {
    @Query(sort: \Session.createdAt, order: .reverse) private var sessions: [Session]

    var body: some View {
        NavigationStack {
            List(sessions) { session in
                NavigationLink {
                    ReportView(session: session)
                } label: {
                    SessionRow(session: session)
                }
            }
            .navigationTitle("训练记录")
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "暂无记录",
                        systemImage: "tennisball",
                        description: Text("完成第一次训练后这里会显示分析报告")
                    )
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading) {
            Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            HStack {
                Label(formatDuration(session.durationSec), systemImage: "clock")
                if let hr = session.avgHeartRate {
                    Label("\(Int(hr)) bpm", systemImage: "heart")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ sec: Double) -> String {
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return "\(m)分\(s)秒"
    }
}
