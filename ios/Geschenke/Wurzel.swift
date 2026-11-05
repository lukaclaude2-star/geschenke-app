import GeschenkeCore
import SwiftUI

/// Wurzel der App: wählt die Farbwelt aus Erscheinung und Dunkelmodus und zeigt Leiste und
/// Startbildschirm.
struct Wurzel: View {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.colorScheme) private var schema
    @State private var startFertig = false
    @State private var zeigeEinfuehrung = false

    var body: some View {
        let palette = aktuellePalette()
        let erzwungen = Designs.erzwingtHell(Erscheinung.aus(zustand.daten.erscheinung))
        ZStack {
            ZuhauseTabs()
                // Farbwelt gewechselt → alles neu zeichnen (Look liest die Farben statisch).
                .id(palette.hell)
            if !startFertig {
                StartBildschirm {
                    startFertig = true
                    // Einführung erst nach dem Start, nur beim ersten Mal (Apple HIG: Onboarding
                    // gehört nicht zum Startvorgang)
                    if !zustand.daten.einfuehrungGesehen {
                        withAnimation(.easeOut(duration: 0.3)) { zeigeEinfuehrung = true }
                    }
                }
                .zIndex(1)
            }
            if zeigeEinfuehrung {
                EinfuehrungView {
                    zustand.setzeEinfuehrungGesehen()
                    withAnimation(.easeOut(duration: 0.3)) { zeigeEinfuehrung = false }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .dynamicTypeSize(Schriftstufe.aus(zustand.daten.schriftgroesse).groesse)
        .tint(Look.akzentText)
        .font(.zuhause(.body))
        .preferredColorScheme(erzwungen.map { $0 ? .light : .dark })
    }

    /// Look ist statisch und muss stehen, bevor die Kinder gezeichnet werden.
    private func aktuellePalette() -> Palette {
        let palette = Designs.palette(erscheinung: Erscheinung.aus(zustand.daten.erscheinung),
                                      systemDunkel: schema == .dark)
        Look.palette = palette
        return palette
    }
}
