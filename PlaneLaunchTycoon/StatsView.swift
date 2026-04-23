import SwiftUI

struct StatsView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        NavigationStack {
            ZStack {
                SoaringSkyBackground()
                    .ignoresSafeArea()

                List {
                    Section("Airline") {
                        LabeledContent("Cash on hand", value: game.formattedMoney(game.money))
                            .listRowBackground(statsRowBackground)
                        LabeledContent("Total launches", value: "\(game.totalLaunches)")
                            .listRowBackground(statsRowBackground)
                        LabeledContent("Best distance", value: "\(Int(game.bestDistanceMeters)) m")
                            .listRowBackground(statsRowBackground)
                        LabeledContent("Career distance", value: "\(Int(game.totalMetersFlown)) m")
                            .listRowBackground(statsRowBackground)
                    }

                    Section("Fleet bonuses") {
                        ForEach(UpgradeKind.allCases) { kind in
                            LabeledContent(kind.title, value: "Lv \(game.level(of: kind))")
                                .listRowBackground(statsRowBackground)
                        }
                    }

                    Section {
                        Text("CI builds an unsigned device .app for compile checks; installable builds need your Mac, Xcode, and signing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Operations")
        }
    }

    private var statsRowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.22))
    }
}

#Preview {
    StatsView()
        .environment(GameModel())
}
