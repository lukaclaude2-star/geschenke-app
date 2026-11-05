import GeschenkeCore
import SwiftUI

/// Sammelsuche: mehrere gespeicherte Profile anhaken und gemeinsam wischen (z. B. Weihnachten).
/// Die Auswahl wird bewusst nicht gespeichert.
struct SammelAuswahlView: View {
    @EnvironmentObject private var zustand: AppZustand
    @State private var gewaehlt: Set<UUID>
    @State private var ziel: WischZiel?

    /// Vom Weihnachts-Countdown kommen alle Profile vorausgewählt.
    init(vorauswahl: Set<UUID> = []) {
        _gewaehlt = State(initialValue: vorauswahl)
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(zustand.daten.profile) { eintrag in
                        Button {
                            if gewaehlt.contains(eintrag.id) { gewaehlt.remove(eintrag.id) } else { gewaehlt.insert(eintrag.id) }
                        } label: {
                            HStack {
                                Image(systemName: gewaehlt.contains(eintrag.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Look.akzent)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(eintrag.name).font(.app(.headline, .halbfett)).foregroundStyle(Look.text)
                                    Text(eintrag.profil.zusammenfassung)
                                        .font(.app(.caption))
                                        .foregroundStyle(Look.leise)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Jede Karte zeigt, für wen sie gedacht ist. Ausschlüsse und Budget gelten pro Person.")
                }
                .listRowBackground(Look.karte)
            }
            Button("Los (\(gewaehlt.count))") {
                // Reihenfolge wie in der Profilliste, damit „für …“ stabil bleibt.
                let personen = zustand.daten.profile.filter { gewaehlt.contains($0.id) }.map(WischPerson.init)
                ziel = WischZiel(personen: personen)
            }
            .buttonStyle(GoldKnopf())
            .disabled(gewaehlt.count < 2)
            .opacity(gewaehlt.count < 2 ? 0.5 : 1)
            .padding()
        }
        .nachtblau()
        .navigationTitle("Für mehrere suchen")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $ziel) { WischZielView(ziel: $0) }
    }
}
