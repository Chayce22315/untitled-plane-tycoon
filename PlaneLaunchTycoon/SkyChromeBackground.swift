import SwiftUI

/// Shared sky treatment for Launch, Upgrades, and Stats (layered 2D depth).
struct SoaringSkyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.78, blue: 1),
                    Color(red: 0.2, green: 0.48, blue: 0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .offset(y: 40)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.75, green: 0.88, blue: 1).opacity(0.5),
                                    Color(red: 0.35, green: 0.65, blue: 0.95).opacity(0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: w * 1.35, height: h * 0.42)
                        .offset(y: h * 0.38)
                        .blur(radius: 1)

                    ForEach(0 ..< 4, id: \.self) { i in
                        cloudPuff(seed: i, in: geo.size)
                    }
                }
            }
        }
    }

    private func cloudPuff(seed: Int, in size: CGSize) -> some View {
        let xFrac = [0.12, 0.38, 0.62, 0.82][seed % 4]
        let yFrac = [0.14, 0.22, 0.18, 0.26][seed % 4]
        let w = size.width * (0.42 + CGFloat(seed % 3) * 0.06)
        return Ellipse()
            .fill(Color.white.opacity(0.38 - Double(seed) * 0.04))
            .frame(width: w, height: w * 0.35)
            .offset(x: size.width * xFrac - size.width * 0.5, y: size.height * yFrac - size.height * 0.35)
            .shadow(color: .white.opacity(0.35), radius: 0, x: 0, y: -2)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 18)
    }
}
