import GeschenkeCore
import SwiftUI

struct MerklisteView: View {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.openURL) private var oeffnen
    @Environment(\.dynamicTypeSize) private var schriftgroesse

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
        if Look.stil == .zuhause {
            zuhause
        } else {
            liste
        }
    }

    private var liste: some View {
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

    // MARK: Zuhause-Stil (Entwurf 2026-11-05-screens): nach Person gruppiert, Fotos auf Creme

    private var zuhause: some View {
        let anzahl = zustand.daten.merkliste.count
        return List {
            Section {
                if anzahl == 0 {
                    VStack(spacing: 10) {
                        Image("coco-geschenk").resizable().scaledToFit().frame(width: 110)
                            .accessibilityHidden(true)
                        Text("Noch nichts gemerkt. Was du beim Wischen nach rechts schiebst, landet hier.")
                            .font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Look.karte)
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: 10) {
                        Text("merkliste").font(.zuhause(.largeTitle, .extrafett)).foregroundStyle(Look.text)
                        Image("coco-stapel").resizable().scaledToFit().frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    if anzahl > 0 {
                        Text(untertitel).font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
                    }
                }
                .textCase(nil)
                .padding(.bottom, 4)
            }
            ForEach(gruppen) { gruppe in
                Section {
                    ForEach(gruppe.eintraege) { eintrag in
                        zuhauseZeile(eintrag)
                    }
                    .onDelete { indizes in
                        zustand.entferneMerk(indizes.map { gruppe.eintraege[$0].id })
                    }
                    .listRowBackground(Look.karte)
                    .listRowSeparatorTint(Color(hex: Look.palette.hell ? 0xE6D9C3 : 0x3A2516))
                } header: {
                    Text("für \(gruppe.fuer)").font(.zuhause(.footnote, .fett)).foregroundStyle(Look.leise)
                        .textCase(nil)
                }
            }
        }
        .listSectionSpacing(14)
        .nachtblau()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var untertitel: String {
        let ideen = zustand.daten.merkliste.count
        let personen = gruppen.count
        return "\(ideen) \(ideen == 1 ? "Idee" : "Ideen") für \(personen) \(personen == 1 ? "Person" : "Personen")"
    }

    private func zuhauseZeile(_ eintrag: MerkEintrag) -> some View {
        Button {
            if let url = URL(string: eintrag.karte.link) { oeffnen(url) }
        } label: {
            let text = VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.karte.titel).font(.zuhause(.subheadline, .halbfett))
                    .foregroundStyle(Look.text).lineLimit(3)
                Text(eintrag.karte.preisText).font(.zuhause(.footnote, .fett)).foregroundStyle(Look.preis)
                Text(eintrag.karte.shop).font(.zuhause(.footnote)).foregroundStyle(Look.leise).lineLimit(1)
            }
            Group {
                if schriftgroesse.isAccessibilitySize {
                    // sehr große Schrift: Foto über dem Text, damit der Titel die ganze Breite hat
                    VStack(alignment: .leading, spacing: 8) {
                        ZuhauseFoto(karte: eintrag.karte, ecken: 10).frame(width: 88, height: 88)
                        text
                    }
                } else {
                    HStack(spacing: 12) {
                        ZuhauseFoto(karte: eintrag.karte, ecken: 10).frame(width: 58, height: 58)
                        text
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(Look.leise)
                    }
                }
            }
            .frame(minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
