import Foundation
import Observation

enum UpgradeKind: String, CaseIterable, Identifiable, Sendable {
    case engine
    case wings
    case fuel
    case runway
    case marketing
    case scoreMultiplier
    case autopilot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .engine: "Jet engine"
        case .wings: "Wing profile"
        case .fuel: "Fuel tanks"
        case .runway: "Runway extension"
        case .marketing: "Ticket pricing"
        case .scoreMultiplier: "Distance multiplier"
        case .autopilot: "Autopilot fleet"
        }
    }

    var detail: String {
        switch self {
        case .engine: "More thrust at launch."
        case .wings: "Better lift, slower fall."
        case .fuel: "Stay airborne longer."
        case .runway: "Higher starting speed."
        case .marketing: "Earn more per meter flown."
        case .scoreMultiplier: "Starts at ×1. Each level adds to the landing score multiplier and coin payout."
        case .autopilot: "Passive income while away."
        }
    }

    var icon: String {
        switch self {
        case .engine: "flame.fill"
        case .wings: "wind"
        case .fuel: "fuelpump.fill"
        case .runway: "road.lanes"
        case .marketing: "dollarsign.circle.fill"
        case .scoreMultiplier: "multiply.circle.fill"
        case .autopilot: "airplane.circle"
        }
    }

    func cost(forLevel level: Int) -> Double {
        let base: Double = switch self {
        case .engine: 25
        case .wings: 40
        case .fuel: 35
        case .runway: 50
        case .marketing: 80
        case .scoreMultiplier: 70
        case .autopilot: 200
        }
        return (base * pow(1.18, Double(level))).rounded(.up)
    }
}

@MainActor
@Observable
final class GameModel {
    private(set) var money: Double = 0
    private(set) var totalLaunches: Int = 0
    private(set) var bestDistanceMeters: Double = 0
    private(set) var totalMetersFlown: Double = 0

    private(set) var upgradeLevels: [UpgradeKind: Int] = [:]

    /// 0...1 launch power (from swipe: lower on screen = stronger)
    var launchCharge: Double = 0
    private(set) var phase: LaunchPhase = .idle

    /// Samples normalized 0...1 x and altitude for the last flight path
    private(set) var lastFlightPath: [FlightSample] = []

    /// Last throw: base meters, score multiplier (upgrade; base ×1), coins applied after landing animation
    private(set) var lastBaseMeters: Double = 0
    private(set) var lastScoreMultiplier: Double = 1
    private(set) var lastTotalMetersDisplay: Double = 0
    private(set) var pendingCoinReward: Double = 0

    /// Easter egg: typing the longest phobia name unlocks the Admin tab.
    private(set) var adminUnlocked: Bool = false

    /// `nonisolated(unsafe)` so `deinit` can cancel tasks; `@Observable` rejects plain `nonisolated` on mutable vars.
    nonisolated(unsafe) private var autopilotTask: Task<Void, Never>?
    nonisolated(unsafe) private var landTask: Task<Void, Never>?

    enum LaunchPhase: Sendable {
        case idle
        case charging
        case flying
        case landed
    }

    struct FlightSample: Sendable {
        var x: Double
        var y: Double
    }

    init() {
        for kind in UpgradeKind.allCases {
            upgradeLevels[kind] = 0
        }
        startAutopilotIfNeeded()
    }

    deinit {
        autopilotTask?.cancel()
        landTask?.cancel()
    }

    func level(of kind: UpgradeKind) -> Int {
        upgradeLevels[kind, default: 0]
    }

    func beginCharging() {
        guard phase == .idle else { return }
        landTask?.cancel()
        landTask = nil
        phase = .charging
        launchCharge = 0
    }

    /// `normalizedPowerY` in 0...1: 0 = top of power zone (weakest), 1 = bottom (strongest)
    func updateLaunchPower(normalizedPowerY: Double) {
        guard phase == .charging else { return }
        launchCharge = min(1, max(0, normalizedPowerY))
    }

    func releaseLaunch(screenWidth: CGFloat, screenHeight: CGFloat) {
        guard phase == .charging else { return }
        let power = max(0.08, launchCharge)
        launchCharge = 0
        phase = .flying

        let path = Self.simulateFlight(
            power: power,
            engine: level(of: .engine),
            wings: level(of: .wings),
            fuel: level(of: .fuel),
            runway: level(of: .runway),
            marketing: level(of: .marketing),
            width: max(320, Double(screenWidth)),
            height: max(400, Double(screenHeight))
        )

        lastFlightPath = path.samples
        let distance = path.distanceMeters
        let marketing = Double(level(of: .marketing))
        let multLevel = Double(level(of: .scoreMultiplier))
        let scoreMultiplier = 1 + 0.06 * multLevel
        let totalMetersDisplay = distance * scoreMultiplier
        let perMeter = 0.35 + marketing * 0.12
        let baseRevenue = distance * perMeter * (0.85 + power * 0.25)
        let coins = max(1, (baseRevenue * scoreMultiplier).rounded(.down))

        lastBaseMeters = distance
        lastScoreMultiplier = scoreMultiplier
        lastTotalMetersDisplay = totalMetersDisplay
        pendingCoinReward = coins

        totalLaunches += 1
        totalMetersFlown += distance
        bestDistanceMeters = max(bestDistanceMeters, distance)

        landTask?.cancel()
        let sampleCount = max(path.samples.count, 2)
        let duration = max(1.25, min(5.5, Double(sampleCount) * 0.055))
        landTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, !Task.isCancelled else { return }
            if self.phase == .flying {
                self.phase = .landed
            }
        }
    }

    func applyPendingCoinReward() {
        guard pendingCoinReward > 0 else { return }
        money += pendingCoinReward
        pendingCoinReward = 0
    }

    func resetFlightVisual() {
        if phase == .landed {
            landTask?.cancel()
            landTask = nil
            phase = .idle
            lastFlightPath = []
            lastBaseMeters = 0
            lastScoreMultiplier = 1
            lastTotalMetersDisplay = 0
        }
    }

    func canAfford(_ kind: UpgradeKind) -> Bool {
        money >= kind.cost(forLevel: level(of: kind))
    }

    @discardableResult
    func purchase(_ kind: UpgradeKind) -> Bool {
        let lvl = level(of: kind)
        let price = kind.cost(forLevel: lvl)
        guard money >= price else { return false }
        money -= price
        upgradeLevels[kind] = lvl + 1
        if kind == .autopilot {
            restartAutopilot()
        }
        return true
    }

    func enableAdminPanel() {
        adminUnlocked = true
    }

    func disableAdminPanel() {
        adminUnlocked = false
    }

    func adminGrantMoney(_ amount: Double) {
        guard adminUnlocked else { return }
        money += max(0, amount)
    }

    func adminSetUpgradeLevel(_ kind: UpgradeKind, level: Int) {
        guard adminUnlocked else { return }
        let clamped = min(99, max(0, level))
        upgradeLevels[kind] = clamped
        if kind == .autopilot {
            restartAutopilot()
        }
    }

    func adminMaxAllUpgrades(cap: Int) {
        guard adminUnlocked else { return }
        let c = min(99, max(0, cap))
        for kind in UpgradeKind.allCases {
            upgradeLevels[kind] = c
        }
        restartAutopilot()
    }

    func adminResetProgress() {
        guard adminUnlocked else { return }
        landTask?.cancel()
        landTask = nil
        autopilotTask?.cancel()
        autopilotTask = nil
        money = 0
        totalLaunches = 0
        bestDistanceMeters = 0
        totalMetersFlown = 0
        launchCharge = 0
        phase = .idle
        lastFlightPath = []
        lastBaseMeters = 0
        lastScoreMultiplier = 1
        lastTotalMetersDisplay = 0
        pendingCoinReward = 0
        for kind in UpgradeKind.allCases {
            upgradeLevels[kind] = 0
        }
        startAutopilotIfNeeded()
    }

    private func startAutopilotIfNeeded() {
        restartAutopilot()
    }

    private func restartAutopilot() {
        autopilotTask?.cancel()
        let level = level(of: .autopilot)
        guard level > 0 else { return }
        autopilotTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                guard let self, !Task.isCancelled else { return }
                let passive = 3.0 + Double(self.level(of: .autopilot)) * 2.2
                self.money += passive * (1 + 0.05 * Double(self.level(of: .marketing)))
            }
        }
    }

    private struct SimResult: Sendable {
        var samples: [FlightSample]
        var distanceMeters: Double
        var revenue: Double
    }

    private static func simulateFlight(
        power: Double,
        engine: Int,
        wings: Int,
        fuel: Int,
        runway: Int,
        marketing: Int,
        width: Double,
        height: Double
    ) -> SimResult {
        let dt = 1.0 / 60.0
        let maxTime = 6.0 + Double(fuel) * 0.35

        var x: Double = 0
        var y: Double = 0
        var vx = (180 + Double(runway) * 22) * (0.55 + power * 0.55)
        var vy = (95 + Double(engine) * 18) * (0.4 + power * 0.75)

        let gravity = 165 * (1 - min(0.55, Double(wings) * 0.06))
        let dragX = 0.988 - min(0.02, Double(wings) * 0.002)
        let dragY = 0.995

        var samples: [FlightSample] = []
        var maxX = x
        var t = 0.0

        let scaleX = width * 0.92
        let scaleY = height * 0.55

        while t < maxTime, y >= -5, vx > 8 {
            x += vx * dt
            y += vy * dt
            vy -= gravity * dt
            vx *= pow(dragX, dt * 60)
            vy *= pow(dragY, dt * 60)
            maxX = max(maxX, x)
            t += dt

            let nx = min(1, x / scaleX)
            let ny = min(1, max(0, y / scaleY))
            if samples.count < 2 || t - (Double(samples.count) * 0.04) > 0 {
                samples.append(FlightSample(x: nx, y: ny))
            }
        }

        let distanceMeters = maxX / 3.5
        let perMeter = 0.35 + Double(marketing) * 0.12
        let revenue = (distanceMeters * perMeter * (0.85 + power * 0.25)).rounded(.down)

        return SimResult(samples: samples, distanceMeters: distanceMeters, revenue: max(1, revenue))
    }
}

extension GameModel {
    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    func formattedMoney(_ value: Double) -> String {
        Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}
