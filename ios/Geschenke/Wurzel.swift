import GeschenkeCore
import SwiftUI

/// Wurzel der App: wählt die Palette aus Design, Erscheinung und Dunkelmodus des Systems und
/// zeigt im Zuhause-Stil Leiste und Startbildschirm, sonst die bisherige Startseite.
struct Wurzel: View {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.colorScheme) private var schema
    @State private var startFertig = false

    var body: some View {
        let palette = aktuellePalette()
        let erscheinung = Erscheinung.aus(zustand.daten.erscheinung)
        let erzwungen = Designs.erzwingtHell(zustand.daten.design, erscheinung: erscheinung)
        let schemaWahl: ColorScheme? = erzwungen.map { $0 ? .light : .dark }
        let schlussel = "\(palette.id)-\(palette.hell)"
        ZStack {
            Group {
                if palette.stil == .zuhause {
                    ZuhauseTabs()
                } else {
                    NavigationStack { StartView() }
                }
            }
            // Palette gewechselt → alles neu zeichnen (Look liest die Farben statisch).
            .id(schlussel)
            if palette.stil == .zuhause && !startFertig {
                StartBildschirm { startFertig = true }
                    .zIndex(1)
            }
        }
        // Das Blatt hängt außerhalb von .id, damit es beim Durchprobieren der Designs offen bleibt.
        .sheet(isPresented: $zustand.zeigeEinstellungen) {
            EinstellungenView()
                .environmentObject(zustand)
                .dynamicTypeSize(Schriftstufe.aus(zustand.daten.schriftgroesse).groesse)
                .preferredColorScheme(schemaWahl)
                .id(schlussel)
        }
        .dynamicTypeSize(Schriftstufe.aus(zustand.daten.schriftgroesse).groesse)
        .tint(Look.akzent)
        .fontDesign(Look.stil == .deco ? .serif : .default)
        .font(Look.stil == .zuhause ? Font.zuhause(.body) : Font.body)
        .preferredColorScheme(schemaWahl)
    }

    /// Look ist statisch und muss stehen, bevor die Kinder gezeichnet werden.
    private func aktuellePalette() -> Palette {
        let palette = Designs.palette(zustand.daten.design,
                                      erscheinung: Erscheinung.aus(zustand.daten.erscheinung),
                                      systemDunkel: schema == .dark)
        Look.palette = palette
        return palette
    }
}
