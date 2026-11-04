import GeschenkeCore
import SwiftUI

/// „Was ich gelernt habe“: Schieberegler je Schlagwort, Ausschlüsse, Zurücksetzen (Grundbaustein 6).
/// In der Sammelsuche wählt man oben die Person.
struct GelerntView: View {
    @ObservedObject var modell: KartenStapelModell
    @Environment(\.dismiss) private var schliessen
    @State private var person = 0
    /// Reihenfolge beim Öffnen einfrieren – sonst springen Zeilen beim Ziehen unter dem Finger weg.
    @State private var reihenfolge: [String] = []

    private var eintraege: [GewichtEintrag] {
        let alle = modell.personen[person].gewichtung.eintraege
        let platz = Dictionary(uniqueKeysWithValues: reihenfolge.enumerated().map { ($1, $0) })
        return alle.sorted { (platz[$0.tag] ?? Int.max, $0.tag) < (platz[$1.tag] ?? Int.max, $1.tag) }
    }

    var body: some View {
        NavigationStack {
            List {
                if modell.istSammel {
                    Picker("Person", selection: $person) {
                        ForEach(modell.personen.indices, id: \.self) { i in
                            Text(modell.name(i)).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(eintraege) { eintrag in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(eintrag.label)
                                Spacer()
                                Text(Gewichtung.stufe(eintrag.gewicht))
                                    .font(.app(.caption, .fett))
                                    .foregroundStyle(Look.akzent)
                            }
                            Slider(value: Binding(
                                get: { eintrag.gewicht },
                                set: { modell.setze(eintrag.tag, auf: $0, person: person) }
                            ), in: Gewichtung.minimum...Gewichtung.maximum)
                        }
                    }
                } header: {
                    Text("Was ich gelernt habe")
                } footer: {
                    Text("Zieh nach rechts für mehr davon, nach links für weniger.")
                }
                .listRowBackground(Look.karte)

                if !modell.ausschluesse(person: person).isEmpty {
                    Section("Nie zeigen") {
                        ForEach(modell.ausschluesse(person: person), id: \.schluessel) { ausschluss in
                            Label(ausschluss.label, systemImage: "nosign")
                        }
                    }
                    .listRowBackground(Look.karte)
                }

                Section {
                    Button {
                        modell.zuruecksetzen(person: person)
                        reihenfolge = modell.personen[person].gewichtung.eintraege.map(\.tag)
                    } label: {
                        Label("Alles zurücksetzen", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(Look.akzent)
                    }
                    Button {
                        Task { await modell.gesehenZuruecksetzen() }
                        schliessen()
                    } label: {
                        Label("Gesehene wieder zeigen", systemImage: "eye")
                            .foregroundStyle(Look.akzent)
                    }
                } footer: {
                    Text("Bereits gewischte Karten dürfen dann wieder auftauchen.")
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
        .onAppear { reihenfolge = modell.personen[person].gewichtung.eintraege.map(\.tag) }
        .onChange(of: person) { reihenfolge = modell.personen[person].gewichtung.eintraege.map(\.tag) }
    }
}
