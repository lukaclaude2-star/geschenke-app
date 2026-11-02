import SwiftUI

@main
struct GeschenkeApp: App {
    @StateObject private var zustand = AppZustand()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                StartView()
            }
            .environmentObject(zustand)
            .tint(Look.gold)
            .preferredColorScheme(.dark)
        }
    }
}
