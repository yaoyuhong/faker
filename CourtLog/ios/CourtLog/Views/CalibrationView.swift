import SwiftUI

/// User taps 4 court corners on camera overlay (stored as normalized 0–1).
struct CalibrationView: View {
    @Binding var points: [CGPoint]
    @Binding var overlaySize: CGSize
    let onContinue: () -> Void

    private let labels = ["近端左角", "近端右角", "远端右角", "远端左角"]

    var body: some View {
        VStack {
            Text("标定球场四角")
                .font(.headline)
            Text("请依次点击：\(labels[safe: points.count] ?? "完成")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.85))
                        .overlay { CourtOverlayGuide() }

                    ForEach(Array(displayPoints(in: geo.size).enumerated()), id: \.offset) { index, point in
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard points.count < 4, geo.size.width > 0, geo.size.height > 0 else { return }
                            overlaySize = geo.size
                            let nx = value.location.x / geo.size.width
                            let ny = value.location.y / geo.size.height
                            points.append(CGPoint(x: min(max(nx, 0), 1), y: min(max(ny, 0), 1)))
                        }
                )
                .onAppear { overlaySize = geo.size }
                .onChange(of: geo.size) { _, newSize in overlaySize = newSize }
            }
            .aspectRatio(9 / 16, contentMode: .fit)
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

    private func displayPoints(in size: CGSize) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
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
