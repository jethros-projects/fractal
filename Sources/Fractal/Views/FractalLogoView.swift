import SwiftUI

struct FractalLogoMark: View {
    var body: some View {
        FractalLogoShape()
            .stroke(
                style: StrokeStyle(
                    lineWidth: 1.7,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct FractalLogoShape: Shape {
    private let triangles: [[CGPoint]] = [
        [CGPoint(x: 32, y: 6), CGPoint(x: 1.98, y: 58), CGPoint(x: 62.02, y: 58)],
        [CGPoint(x: 16.99, y: 32), CGPoint(x: 47.01, y: 32), CGPoint(x: 32, y: 58)],
        [CGPoint(x: 24.5, y: 19), CGPoint(x: 39.5, y: 19), CGPoint(x: 32, y: 32)],
        [CGPoint(x: 9.49, y: 45), CGPoint(x: 24.5, y: 45), CGPoint(x: 16.99, y: 58)],
        [CGPoint(x: 39.5, y: 45), CGPoint(x: 54.51, y: 45), CGPoint(x: 47.01, y: 58)]
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()

        for triangle in triangles {
            guard triangle.count == 3 else {
                continue
            }

            path.move(to: point(from: triangle[0], in: rect))
            path.addLine(to: point(from: triangle[1], in: rect))
            path.addLine(to: point(from: triangle[2], in: rect))
            path.closeSubpath()
        }

        return path
    }

    private func point(from source: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + (source.x / 64) * rect.width,
            y: rect.minY + (source.y / 64) * rect.height
        )
    }
}
