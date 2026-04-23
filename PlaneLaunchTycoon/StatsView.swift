import SwiftUI

struct StatsView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        NavigationStack {
            List {
                Section("Airline") {
                    LabeledContent("Cash on hand", value: game.formattedMoney(game.money))
                    LabeledContent("Total launches", value: "\(game.totalLaunches)")
                    LabeledContent("Best distance", value: "\(Int(game.bestDistanceMeters)) m")
                    LabeledContent("Career distance", value: "\(Int(game.totalMetersFlown)) m")
                }

                Section("Fleet bonuses") {
                    ForEach(UpgradeKind.allCases) { kind in
                        LabeledContent(kind.title, value: "Lv \(game.level(of: kind))")
                    }
                }

                Section {
                    Text("CI builds an unsigned device .app for compile checks; installable builds need your Mac, Xcode, and signing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Operations")
        }
    }
}

#Preview {
    StatsView()
        .environment(GameModel())
}
