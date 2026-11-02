import SwiftUI

@main
struct GeschenkeApp: App {
    @StateObject private var zustand = AppZustand()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                StartView()
            }
            // Design gewechselt → alles neu zeichnen (Look liest die Farben statisch).
            .id(zustand.daten.design)
            // Das Blatt hängt außerhalb von .id, damit es beim Durchprobieren der Designs offen bleibt.
            .sheet(isPresented: $zustand.zeigeEinstellungen) {
                EinstellungenView()
                    .environmentObject(zustand)
                    .preferredColorScheme(Look.palette.hell ? .light : .dark)
                    .id(zustand.daten.design)
            }
            .environmentObject(zustand)
            .tint(Look.akzent)
            .fontDesign(Look.stil == .deco ? .serif : .default)
            .preferredColorScheme(Look.palette.hell ? .light : .dark)
        }
    }
}
