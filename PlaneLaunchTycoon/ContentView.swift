import SwiftUI

struct ContentView: View {
    @Environment(GameModel.self) private var game
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            TabView(selection: $selectedTab) {
                RunwayLaunchView()
                    .tabItem {
                        Label {
                            Text("Launch")
                        } icon: {
                            Image("SoaringPlaneTab")
                                .renderingMode(.original)
                        }
                    }
                    .tag(0)

                UpgradeStoreView()
                    .tabItem { Label("Upgrades", systemImage: "cart.fill") }
                    .tag(1)

                StatsView()
                    .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                    .tag(2)
            }
            .tint(.cyan)

            coinBadge
                .padding(.leading, 14)
                .padding(.top, 6)
                .allowsHitTesting(false)
        }
    }

    private var coinBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .white.opacity(0.9))
            Text(game.formattedMoney(game.money))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

#Preview {
    ContentView()
        .environment(GameModel())
}
