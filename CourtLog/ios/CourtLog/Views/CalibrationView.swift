import SwiftUI

/// User taps 4 court corners on a frozen camera frame.
struct CalibrationView: View {
    @Binding var points: [CGPoint]
    let onContinue: () -> Void

    private let labels = ["近端左角", "近端右角", "远端右角", "远端左角"]

    var body: some View {
        VStack {
            Text("标定球场四角")
                .font(.headline)
            Text("请依次点击 \(labels[safe: points.count] ?? "完成")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.85))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        CourtOverlayGuide()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard points.count < 4 else { return }
                                points.append(value.location)
                            }
                    )

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(.yellow)
                        .frame(width: 16, height: 16)
                        .position(point)
                        .overlay {
                            Text("\(index + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(.black)
                                .position(point)
                        }
                }
            }
            .padding()

            HStack {
                Button("重置") { points.removeAll() }
                    .disabled(points.isEmpty)

                Spacer()

                Button("下一步") { onContinue() }
                    .buttonStyle(.borderedProminent)
                    .disabled(points.count < 4)
            }
            .padding(.horizontal)
        }
    }
}

struct CourtOverlayGuide: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let inset = geo.size.width * 0.1
                let rect = CGRect(
                    x: inset,
                    y: geo.size.height * 0.2,
                    width: geo.size.width - inset * 2,
                    height: geo.size.height * 0.6
                )
                path.addRect(rect)
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            }
            .stroke(.white.opacity(0.4), lineWidth: 2)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
