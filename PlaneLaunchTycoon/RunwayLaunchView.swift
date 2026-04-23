import SwiftUI

struct RunwayLaunchView: View {
    @Environment(GameModel.self) private var game
    @State private var layout = CGSize(width: 390, height: 520)
    @State private var landingStage: LandingOverlayStage = .hidden
    @State private var slotDisplayTotal: Int = 0
    @State private var slotDigitOffsets: [CGFloat] = [0, 0, 0, 0, 0, 0]
    @State private var mergeProgress: CGFloat = 0

    private let powerBarWidth: CGFloat = 14
    private let swipeStartMaxY: CGFloat = 120

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    skyGradient
                        .ignoresSafeArea(edges: .top)

                    FlightCanvasView(
                        samples: game.lastFlightPath,
                        phase: game.phase,
                        charge: game.launchCharge
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if game.phase == .flying {
                        liveMetersHud(baseMeters: game.lastBaseMeters, samples: game.lastFlightPath)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 56)
                    }

                    if game.phase == .charging {
                        powerBarOverlay(size: size)
                    }

                    if game.phase == .landed {
                        landingResultsOverlay
                    }

                    VStack {
                        Spacer(minLength: 0)
                        bottomHint(size: size)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .allowsHitTesting(game.phase != .flying && game.phase != .landed)
                }
                .contentShape(Rectangle())
                .highPriorityGesture(powerSwipeGesture(in: size))
                .onAppear { layout = size }
                .onChange(of: size) { _, new in layout = new }
                .onChange(of: game.phase) { _, new in
                    if new == .landed {
                        startLandingSequence()
                    } else if new == .idle {
                        landingStage = .hidden
                        mergeProgress = 0
                    }
                }
                .onChange(of: landingStage) { _, new in
                    if new == .mergingMultiplier {
                        mergeProgress = 0
                        withAnimation(.easeOut(duration: 0.5)) {
                            mergeProgress = 1
                        }
                    }
                }
            }
            .navigationTitle("Paper Tycoon")
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
                Color(red: 0.5, green: 0.82, blue: 1),
                Color(red: 0.22, green: 0.52, blue: 0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func powerBarOverlay(size: CGSize) -> some View {
        let zoneHeight = size.height * 0.42
        return VStack {
            HStack {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: powerBarWidth, height: zoneHeight)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.95), Color.yellow],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: powerBarWidth, height: max(6, zoneHeight * game.launchCharge))
                }
                .frame(height: zoneHeight, alignment: .bottom)
                .padding(.leading, 20)
                Spacer()
            }
            .padding(.top, size.height * 0.1)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func liveMetersHud(baseMeters: Double, samples: [GameModel.FlightSample]) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: samples.isEmpty)) { timeline in
            let progress = flightProgress(samples: samples, date: timeline.date)
            let m = baseMeters * progress
            Text("\(Int(m)) m")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
    }

    private func flightProgress(samples: [GameModel.FlightSample], date: Date) -> Double {
        guard samples.count > 1 else { return 0 }
        let span = max(samples.count - 1, 1)
        let tick = Int(date.timeIntervalSinceReferenceDate * 14)
        let idx = tick % span
        let x = samples[min(idx, samples.count - 1)].x
        return min(1, max(0, x))
    }

    private func powerSwipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let start = value.startLocation
                if game.phase == .idle, start.y <= swipeStartMaxY, value.translation.height > 14 {
                    game.beginCharging()
                }
                if game.phase == .charging {
                    let zoneTop = size.height * 0.08
                    let zoneBottom = zoneTop + size.height * 0.42
                    let y = value.location.y
                    let t = (y - zoneTop) / max(1, zoneBottom - zoneTop)
                    game.updateLaunchPower(normalizedPowerY: min(1, max(0, t)))
                }
            }
            .onEnded { _ in
                if game.phase == .charging {
                    game.releaseLaunch(screenWidth: layout.width, screenHeight: layout.height)
                }
            }
    }

    private func bottomHint(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if game.phase == .idle {
                Text("Swipe down from the sky to aim power — lower = stronger. Release to throw.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if game.phase == .charging {
                Text("Release to launch your paper plane.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Best: \(Int(game.bestDistanceMeters)) m")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var landingResultsOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                switch landingStage {
                case .hidden:
                    EmptyView()

                case .baseMeters:
                    Text("\(Int(game.lastBaseMeters)) m")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                case .mergingMultiplier:
                    HStack(spacing: 6) {
                        Text("\(Int(game.lastBaseMeters))")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                        Text("×")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                            .scaleEffect(0.6 + 0.4 * mergeProgress)
                            .offset(x: 40 * (1 - mergeProgress), y: -30 * (1 - mergeProgress))
                        Text(String(format: "%.2f", game.lastScoreMultiplier))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                            .offset(x: 50 * (1 - mergeProgress), y: 20 * (1 - mergeProgress))
                    }
                    .foregroundStyle(.white)

                case .slotSpin:
                    slotMachineDigits(value: slotDisplayTotal)
                        .frame(height: 56)

                case .totalShown:
                    Text("\(slotDisplayTotal) m")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                case .coins:
                    VStack(spacing: 12) {
                        Text(game.formattedMoney(game.pendingCoinReward > 0 ? game.pendingCoinReward : 0))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                        Text("Added to balance")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                if landingStage == .coins {
                    Button("Throw again") {
                        game.applyPendingCoinReward()
                        game.resetFlightVisual()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .padding(.top, 8)
                }
            }
            .padding(28)
        }
    }

    private func slotMachineDigits(value: Int) -> some View {
        let s = String(format: "%06d", min(max(value, 0), 999_999))
        return HStack(spacing: 2) {
            ForEach(0 ..< 6, id: \.self) { i in
                let idx = s.index(s.startIndex, offsetBy: i)
                let ch = s[idx]
                slotDigitColumn(char: ch, offset: slotDigitOffsets[i])
            }
        }
    }

    private func slotDigitColumn(char: Character, offset: CGFloat) -> some View {
        let digits = Array("0123456789")
        let h: CGFloat = 44
        return ZStack {
            ForEach(0 ..< 10, id: \.self) { d in
                Text(String(digits[d]))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(height: h)
                    .offset(y: CGFloat(d) * h + offset)
            }
        }
        .frame(width: 28, height: h)
        .clipped()
    }

    private enum LandingOverlayStage {
        case hidden
        case baseMeters
        case mergingMultiplier
        case slotSpin
        case totalShown
        case coins
    }

    private func startLandingSequence() {
        landingStage = .baseMeters
        mergeProgress = 0
        let target = Int(min(game.lastTotalMetersDisplay, 999_999).rounded())
        slotDisplayTotal = Int.random(in: max(1, target - 400) ... max(target + 50, target + 1))
        alignSlotOffsets(to: slotDisplayTotal)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard game.phase == .landed else { return }
            landingStage = .mergingMultiplier
            try? await Task.sleep(for: .milliseconds(600))
            guard game.phase == .landed else { return }
            landingStage = .slotSpin
            await runSlotSpin(to: target)
            guard game.phase == .landed else { return }
            landingStage = .totalShown
            slotDisplayTotal = target
            try? await Task.sleep(for: .milliseconds(800))
            guard game.phase == .landed else { return }
            landingStage = .coins
        }
    }

    private func runSlotSpin(to finalValue: Int) async {
        let digitCount = 6
        slotDigitOffsets = (0 ..< digitCount).map { _ in CGFloat.random(in: -200 ... -40) }
        let finalStr = String(format: "%06d", min(max(finalValue, 0), 999_999))
        let steps = 32
        for step in 0 ..< steps {
            guard game.phase == .landed else { return }
            let t = Double(step + 1) / Double(steps)
            let eased = 1 - pow(1 - t, 2.8)
            var newOffsets: [CGFloat] = []
            for i in 0 ..< digitCount {
                let targetOffset = slotTargetOffset(forDigitAt: i, finalString: finalStr)
                let jitter = CGFloat.random(in: -4 ... 4) * CGFloat(1 - eased)
                let wild = CGFloat.random(in: -320 ... 0) * CGFloat(1 - eased)
                newOffsets.append(wild + jitter + targetOffset * CGFloat(eased))
            }
            slotDigitOffsets = newOffsets
            slotDisplayTotal = Int.random(in: max(0, finalValue - 900) ... finalValue + 500)
            try? await Task.sleep(for: .milliseconds(48))
        }
        slotDisplayTotal = finalValue
        alignSlotOffsets(to: finalValue)
    }

    private func slotTargetOffset(forDigitAt index: Int, finalString: String) -> CGFloat {
        let chars = Array(finalString)
        guard index < chars.count, let d = Int(String(chars[index])) else { return 0 }
        let h: CGFloat = 44
        return -CGFloat(d) * h
    }

    private func alignSlotOffsets(to value: Int) {
        let s = String(format: "%06d", min(max(value, 0), 999_999))
        let h: CGFloat = 44
        var off: [CGFloat] = []
        for ch in s {
            if let d = Int(String(ch)) {
                off.append(-CGFloat(d) * h)
            }
        }
        while off.count < 6 { off.append(0) }
        slotDigitOffsets = off
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                drawPaperPlane(context: &context, size: size, date: timeline.date)
            }
        }
    }

    private func drawRunway(context: inout GraphicsContext, size: CGSize) {
        let runwayRect = CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.28)
        context.fill(
            Path(roundedRect: runwayRect, cornerRadius: 0),
            with: .color(Color(red: 0.55, green: 0.52, blue: 0.48))
        )
        context.stroke(
            Path(CGRect(x: 20, y: size.height * 0.76, width: size.width - 40, height: 3)),
            with: .color(.yellow.opacity(0.85)),
            lineWidth: 2
        )
    }

    private func drawPath(context: inout GraphicsContext, size: CGSize) {
        guard samples.count > 1 else { return }
        var path = Path()
        for (i, s) in samples.enumerated() {
            let pt = CGPoint(x: s.x * size.width, y: size.height * 0.72 - s.y * size.height * 0.55)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        context.stroke(path, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 8]))
    }

    private func drawPaperPlane(context: inout GraphicsContext, size: CGSize, date: Date) {
        let start = CGPoint(x: 36, y: size.height * 0.68 - charge * 36)
        if samples.isEmpty {
            drawPaperAirplane(context: &context, at: start, angle: .degrees(-12 + charge * 18))
            return
        }

        if phase == .flying {
            let t = date.timeIntervalSinceReferenceDate
            let span = max(samples.count - 1, 1)
            let idx = Int(t * 14) % span
            let a = samples[min(idx, samples.count - 1)]
            let b = samples[min(idx + 1, samples.count - 1)]
            let p = CGPoint(x: a.x * size.width, y: size.height * 0.72 - a.y * size.height * 0.55)
            let q = CGPoint(x: b.x * size.width, y: size.height * 0.72 - b.y * size.height * 0.55)
            let angle = atan2(q.y - p.y, q.x - p.x)
            let pos = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
            drawPaperAirplane(context: &context, at: pos, angle: .radians(angle))
        } else if phase == .charging {
            drawPaperAirplane(context: &context, at: start, angle: .degrees(-12 + charge * 18))
        } else {
            let last = samples.last!
            let pos = CGPoint(x: last.x * size.width, y: size.height * 0.72 - last.y * size.height * 0.55)
            drawPaperAirplane(context: &context, at: pos, angle: .degrees(-35))
        }
    }

    private func drawPaperAirplane(context: inout GraphicsContext, at position: CGPoint, angle: Angle) {
        var layer = context
        layer.translateBy(x: position.x, y: position.y)
        layer.rotate(by: angle)

        var nose = Path()
        nose.move(to: CGPoint(x: 34, y: 0))
        nose.addLine(to: CGPoint(x: -22, y: -14))
        nose.addLine(to: CGPoint(x: -14, y: 0))
        nose.addLine(to: CGPoint(x: -22, y: 14))
        nose.closeSubpath()
        layer.fill(nose, with: .color(Color(white: 0.97)))

        var fold = Path()
        fold.move(to: CGPoint(x: 28, y: 0))
        fold.addLine(to: CGPoint(x: -18, y: -10))
        fold.addLine(to: CGPoint(x: -10, y: 0))
        fold.addLine(to: CGPoint(x: -18, y: 10))
        fold.closeSubpath()
        layer.fill(fold, with: .color(Color(white: 0.88)))

        layer.stroke(nose, with: .color(Color(white: 0.55).opacity(0.6)), lineWidth: 0.8)
    }
}

#Preview {
    RunwayLaunchView()
        .environment(GameModel())
}
