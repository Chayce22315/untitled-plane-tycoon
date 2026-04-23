import SwiftUI

@main
struct PlaneLaunchTycoonApp: App {
    @State private var game = GameModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(game)
        }
    }
}
