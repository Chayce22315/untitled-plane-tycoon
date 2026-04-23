import SwiftUI

struct RunwayLaunchView: View {
    @Environment(GameModel.self) private var game
    @State private var layout = CGSize(width: 390, height: 520)

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let size = geo.size
                ZStack(alignment: .bottomLeading) {
                    skyGradient
                        .ignoresSafeArea(edges: .top)

                    FlightCanvasView(
                        samples: game.lastFlightPath,
                        phase: game.phase,
                        charge: game.launchCharge
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        launchPad(size: size)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .onAppear { layout = size }
                .onChange(of: size) { _, new in layout = new }
            }
            .navigationTitle("Untitled Plane Tycoon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(game.formattedMoney(game.money))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var skyGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.75, blue: 1),
                Color(red: 0.2, green: 0.45, blue: 0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func launchPad(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if game.phase == .landed || game.phase == .idle {
                Text("Hold to charge launch, release to fly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if game.phase == .charging {
                ChargeBar(progress: game.launchCharge)
            }

            Text("Best: \(Int(game.bestDistanceMeters)) m")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Group {
                if game.phase == .landed {
                    Button {
                        game.resetFlightVisual()
                    } label: {
                        Text("Tap to launch again")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                } else {
                    HoldLaunchButton(
                        phase: game.phase,
                        onPress: { game.beginCharging() },
                        onRelease: {
                            game.releaseLaunch(screenWidth: layout.width, screenHeight: layout.height)
                        },
                        onDragChanged: { game.updateCharge(delta: $0) }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ChargeBar: View {
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Launch power")
                .font(.caption.weight(.semibold))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, g.size.width * progress))
                }
            }
            .frame(height: 12)
        }
    }
}

private struct HoldLaunchButton: View {
    var phase: GameModel.LaunchPhase
    var onPress: () -> Void
    var onRelease: () -> Void
    var onDragChanged: (TimeInterval) -> Void

    @State private var lastDate = Date()

    var body: some View {
        Text(labelText)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(phase == .charging ? Color.orange : Color.cyan, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.white)
            .opacity(phase == .flying ? 0.55 : 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if phase == .idle {
                            onPress()
                        }
                        if phase == .charging {
                            let now = Date()
                            onDragChanged(now.timeIntervalSince(lastDate))
                            lastDate = now
                        }
                    }
                    .onEnded { _ in
                        if phase == .charging {
                            onRelease()
                        }
                    }
            )
            .allowsHitTesting(phase != .flying)
    }

    private var labelText: String {
        switch phase {
        case .idle: "Hold to launch"
        case .charging: "Release!"
        case .flying: "In flight…"
        case .landed: "Tap to launch again"
        }
    }
}

private struct FlightCanvasView: View {
    var samples: [GameModel.FlightSample]
    var phase: GameModel.LaunchPhase
    var charge: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: samples.isEmpty || phase != .flying)) { timeline in
            Canvas { context, size in
                drawRunway(context: &context, size: size)
                drawPath(context: &context, size: size)
                drawPlane(context: &context, size: size, date: timeline.date)
            }
        }
    }

    private func drawRunway(context: inout GraphicsContext, size: CGSize) {
        let runwayRect = CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.28)
        context.fill(
            Path(roundedRect: runwayRect, cornerRadius: 0),
            with: .color(Color(white: 0.35))
        )
        context.stroke(
            Path(CGRect(x: 20, y: size.height * 0.76, width: size.width - 40, height: 4)),
            with: .color(.yellow.opacity(0.9)),
            lineWidth: 3
        )
    }

    private func drawPath(context: inout GraphicsContext, size: CGSize) {
        guard samples.count > 1 else { return }
        var path = Path()
        for (i, s) in samples.enumerated() {
            let pt = CGPoint(x: s.x * size.width, y: size.height * 0.72 - s.y * size.height * 0.55)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        context.stroke(path, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private func drawPlane(context: inout GraphicsContext, size: CGSize, date: Date) {
        let start = CGPoint(x: 32, y: size.height * 0.68 - charge * 40)
        if samples.isEmpty {
            drawFuselage(context: &context, at: start, angle: .degrees(-8 + charge * 12))
            return
        }

        if phase == .flying {
            let t = date.timeIntervalSinceReferenceDate
            let loop = samples.count
            let idx = Int(t * 14).truncatingRemainder(dividingBy: max(loop - 1, 1))
            let a = samples[min(idx, samples.count - 1)]
            let b = samples[min(idx + 1, samples.count - 1)]
            let p = CGPoint(x: a.x * size.width, y: size.height * 0.72 - a.y * size.height * 0.55)
            let q = CGPoint(x: b.x * size.width, y: size.height * 0.72 - b.y * size.height * 0.55)
            let angle = atan2(q.y - p.y, q.x - p.x)
            let pos = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
            drawFuselage(context: &context, at: pos, angle: .radians(angle))
        } else if phase == .charging {
            drawFuselage(context: &context, at: start, angle: .degrees(-8 + charge * 12))
        } else {
            let last = samples.last!
            let pos = CGPoint(x: last.x * size.width, y: size.height * 0.72 - last.y * size.height * 0.55)
            drawFuselage(context: &context, at: pos, angle: .degrees(-25))
        }
    }

    private func drawFuselage(context: inout GraphicsContext, at position: CGPoint, angle: Angle) {
        var layer = context
        layer.translateBy(x: position.x, y: position.y)
        layer.rotate(by: angle)
        let body = CGRect(x: -28, y: -8, width: 56, height: 16)
        layer.fill(Path(roundedRect: body, cornerRadius: 6), with: .color(.white))
        let wing = CGRect(x: -18, y: 2, width: 36, height: 8)
        layer.fill(Path(roundedRect: wing, cornerRadius: 2), with: .color(Color(red: 0.85, green: 0.2, blue: 0.25)))
        let tail = CGRect(x: -30, y: -12, width: 10, height: 18)
        layer.fill(Path(roundedRect: tail, cornerRadius: 2), with: .color(.white.opacity(0.95)))
    }
}

#Preview {
    RunwayLaunchView()
        .environment(GameModel())
}
