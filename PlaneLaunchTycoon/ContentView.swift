import SwiftUI

struct ContentView: View {
    @Environment(GameModel.self) private var game
    @State private var selectedTab = 0
    @State private var phobiaBuffer = ""
    @FocusState private var phobiaFieldFocused: Bool

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

                if game.adminUnlocked {
                    AdminPanelView()
                        .tabItem { Label("Admin", systemImage: "gearshape.2.fill") }
                        .tag(3)
                }
            }
            .tint(.cyan)
            .onChange(of: game.adminUnlocked) { _, unlocked in
                if !unlocked, selectedTab == 3 {
                    selectedTab = 0
                }
            }

            coinBadge
                .padding(.leading, 14)
                .padding(.top, 6)

            TextField("", text: $phobiaBuffer, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($phobiaFieldFocused)
                .opacity(0.02)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
                .onChange(of: phobiaBuffer) { _, new in
                    let low = new.lowercased()
                    if EasterEggPhobia.matches(low) {
                        game.enableAdminPanel()
                        phobiaBuffer = ""
                        phobiaFieldFocused = false
                        selectedTab = 3
                    } else if low.count > 80 {
                        phobiaBuffer = String(low.suffix(80))
                    }
                }
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
        .onLongPressGesture(minimumDuration: 0.65) {
            phobiaFieldFocused = true
        }
    }
}

#Preview {
    ContentView()
        .environment(GameModel())
}
