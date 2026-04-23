import SwiftUI

struct UpgradeStoreView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        NavigationStack {
            ZStack {
                SoaringSkyBackground()
                    .ignoresSafeArea()

                List {
                    Section {
                        Text("Spend earnings on better launches and passive income. Each level stacks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }

                    Section("Upgrades") {
                        ForEach(UpgradeKind.allCases) { kind in
                            UpgradeRow(kind: kind)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Hangar shop")
        }
    }
}

private struct UpgradeRow: View {
    @Environment(GameModel.self) private var game
    var kind: UpgradeKind

    private var level: Int { game.level(of: kind) }
    private var price: Double { kind.cost(forLevel: level) }
    private var affordable: Bool { game.canAfford(kind) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: kind.icon)
                .font(.title2)
                .frame(width: 36)
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title)
                    .font(.headline)
                Text(kind.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Level \(level)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Button {
                game.purchase(kind)
            } label: {
                Text(game.formattedMoney(price))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(affordable ? .green : .gray)
            .disabled(!affordable)
        }
        .padding(.vertical, 4)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.22))
        )
    }
}

#Preview {
    UpgradeStoreView()
        .environment(GameModel())
}
