import SwiftUI

struct ContentView: View {
    @Environment(GameModel.self) private var game
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RunwayLaunchView()
                .tabItem { Label("Launch", systemImage: "airplane.departure") }
                .tag(0)

            UpgradeStoreView()
                .tabItem { Label("Upgrades", systemImage: "cart.fill") }
                .tag(1)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(2)
        }
        .tint(.cyan)
    }
}

#Preview {
    ContentView()
        .environment(GameModel())
}
