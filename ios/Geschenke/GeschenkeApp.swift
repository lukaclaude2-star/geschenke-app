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
            .tint(Look.akzent)
            .fontDesign(Look.stil == .deco ? .serif : .default)
            .preferredColorScheme(Look.palette.hell ? .light : .dark)
            // Design gewechselt → alles neu zeichnen (Look liest die Farben statisch).
            .id(zustand.daten.design)
        }
    }
}
