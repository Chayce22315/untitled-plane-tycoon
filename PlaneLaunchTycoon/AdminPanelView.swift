import SwiftUI

struct AdminPanelView: View {
    @Environment(GameModel.self) private var game
    @State private var grantAmount: Double = 1_000

    var body: some View {
        NavigationStack {
            ZStack {
                SoaringSkyBackground()
                    .ignoresSafeArea()

                Form {
                    Section {
                        Toggle("Admin mode unlocked", isOn: Binding(
                            get: { game.adminUnlocked },
                            set: { new in
                                if new { game.enableAdminPanel() } else { game.disableAdminPanel() }
                            }
                        ))
                        .tint(.orange)
                    } footer: {
                        Text("Turn off to hide this tab until the Easter egg is entered again.")
                    }

                    Section("Economy") {
                        Stepper(value: $grantAmount, in: 0...9_999_999, step: 500) {
                            Text("Grant: \(game.formattedMoney(grantAmount))")
                        }
                        Button("Add cash") {
                            game.adminGrantMoney(grantAmount)
                        }
                        .tint(.green)
                    }

                    Section("Upgrades") {
                        Button("Max all upgrade levels (50)") {
                            game.adminMaxAllUpgrades(cap: 50)
                        }
                        ForEach(UpgradeKind.allCases) { kind in
                            Stepper(value: Binding(
                                get: { game.level(of: kind) },
                                set: { game.adminSetUpgradeLevel(kind, level: $0) }
                            ), in: 0...99) {
                                Text(kind.title)
                            }
                        }
                    }

                    Section("Danger zone") {
                        Button("Reset game progress", role: .destructive) {
                            game.adminResetProgress()
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Admin")
        }
    }
}

#Preview {
    AdminPanelView()
        .environment(GameModel())
}
