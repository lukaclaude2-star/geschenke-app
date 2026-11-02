import GeschenkeCore
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
                    .dynamicTypeSize(Schriftstufe.aus(zustand.daten.schriftgroesse).groesse)
                    .preferredColorScheme(Look.palette.hell ? .light : .dark)
                    .id(zustand.daten.design)
            }
            .environmentObject(zustand)
            .dynamicTypeSize(Schriftstufe.aus(zustand.daten.schriftgroesse).groesse)
            .tint(Look.akzent)
            .fontDesign(Look.stil == .deco ? .serif : .default)
            .preferredColorScheme(Look.palette.hell ? .light : .dark)
        }
    }
}

extension Schriftstufe {
    /// Normal = iOS-Standard; die Stufen greifen, weil die App Textstile statt fester Größen nutzt.
    var groesse: DynamicTypeSize {
        switch self {
        case .klein: return .small
        case .normal: return .large
        case .gross: return .xLarge
        case .sehrGross: return .xxLarge
        }
    }
}
