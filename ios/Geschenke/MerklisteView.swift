import GeschenkeCore
import SwiftUI

struct MerklisteView: View {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.openURL) private var oeffnen

    private struct Gruppe: Identifiable {
        let fuer: String
        let eintraege: [MerkEintrag]
        var id: String { fuer }
    }

    private var gruppen: [Gruppe] {
        var reihenfolge: [String] = []
        var nachPerson: [String: [MerkEintrag]] = [:]
        for eintrag in zustand.daten.merkliste {
            if nachPerson[eintrag.fuer] == nil { reihenfolge.append(eintrag.fuer) }
            nachPerson[eintrag.fuer, default: []].append(eintrag)
        }
        return reihenfolge.map { Gruppe(fuer: $0, eintraege: nachPerson[$0]!) }
    }

    var body: some View {
        List {
            if zustand.daten.merkliste.isEmpty {
                Text("Noch nichts gemerkt. Wisch Geschenke nach rechts, dann landen sie hier.")
                    .foregroundStyle(Look.leise)
                    .listRowBackground(Look.karte)
            }
            ForEach(gruppen) { gruppe in
                Section(gruppe.fuer) {
                    ForEach(gruppe.eintraege) { eintrag in
                        Button {
                            if let url = URL(string: eintrag.karte.link) { oeffnen(url) }
                        } label: {
                            HStack(spacing: 12) {
                                KartenBild(karte: eintrag.karte, ecken: 8, klein: true)
                                    .frame(width: 76)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(eintrag.karte.titel).foregroundStyle(Look.text).lineLimit(2)
                                    Text(eintrag.karte.preisText)
                                        .font(.caption.bold())
                                        .foregroundStyle(Look.preis)
                                    Text(eintrag.karte.shop)
                                        .font(.caption)
                                        .foregroundStyle(Look.leise)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square").foregroundStyle(Look.akzent)
                            }
                        }
                    }
                    .onDelete { indizes in
                        zustand.entferneMerk(indizes.map { gruppe.eintraege[$0].id })
                    }
                }
                .listRowBackground(Look.karte)
            }
        }
        .nachtblau()
        .navigationTitle("Merkliste")
    }
}
