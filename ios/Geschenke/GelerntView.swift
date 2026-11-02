import GeschenkeCore
import SwiftUI

/// „Was ich gelernt habe“: Schieberegler je Schlagwort, Ausschlüsse, Zurücksetzen (Grundbaustein 6).
struct GelerntView: View {
    @ObservedObject var modell: KartenStapelModell
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(modell.gewichtung.eintraege) { eintrag in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(eintrag.label)
                                Spacer()
                                Text(Gewichtung.stufe(eintrag.gewicht))
                                    .font(.caption.bold())
                                    .foregroundStyle(Look.gold)
                            }
                            Slider(value: Binding(
                                get: { eintrag.gewicht },
                                set: { modell.setze(eintrag.tag, auf: $0) }
                            ), in: Gewichtung.minimum...Gewichtung.maximum)
                        }
                    }
                } header: {
                    Text("Was ich gelernt habe")
                } footer: {
                    Text("Zieh nach rechts für mehr davon, nach links für weniger.")
                }
                .listRowBackground(Look.karte)

                if !modell.ausschluesse.isEmpty {
                    Section("Nie zeigen") {
                        ForEach(modell.ausschluesse, id: \.schluessel) { ausschluss in
                            Label(ausschluss.label, systemImage: "nosign")
                        }
                    }
                    .listRowBackground(Look.karte)
                }

                Section {
                    Button {
                        modell.zuruecksetzen()
                    } label: {
                        Label("Alles zurücksetzen", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(Look.gold)
                    }
                }
                .listRowBackground(Look.karte)
            }
            .nachtblau()
            .navigationTitle("Gewichtung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Fertig") { schliessen() }
            }
        }
        .presentationBackground(Look.hintergrund)
    }
}
