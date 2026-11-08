import GeschenkeCore
import SwiftUI

/// Merkliste: nach Personen oder Kategorien gruppiert, offen ohne Kachelflächen (Entwurf
/// `2026-11-05-runde5`). Wischen nach rechts hakt als gekauft ab, nach links löscht.
struct MerklisteView: View {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.openURL) private var oeffnen
    @Environment(\.dynamicTypeSize) private var schriftgroesse
    /// Knopf „Zum Wischen“ bei leerer Liste: Reiter wechseln oder Blatt schließen.
    var zumWischen: (() -> Void)?
    @State private var frageLoeschen = false

    private var ordnung: MerkOrdnung { MerkOrdnung.aus(zustand.daten.merkOrdnung) }

    var body: some View {
        let liste = zustand.daten.merkliste
        List {
            Section {
                if liste.isEmpty {
                    leer
                } else if liste.count >= 2 {
                    umschalter
                }
            } header: {
                kopf(liste)
            } footer: {
                // Wischaktionen sieht man nicht; bis zum ersten Abhaken steht hier der Hinweis
                if !liste.isEmpty, !liste.contains(where: \.gekauft) {
                    Text("Schon gekauft? Wisch die Idee nach rechts.")
                        .font(.zuhause(.footnote)).foregroundStyle(Look.leise)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            ForEach(merkGruppen(liste, ordnung: ordnung)) { gruppe in
                Section {
                    ForEach(gruppe.eintraege) { zeile($0) }
                } header: {
                    gruppenKopf(gruppe)
                }
                .offeneZeilen()
            }
        }
        .listSectionSpacing(10)
        .animation(.easeOut(duration: 0.25), value: liste)
        .zuhauseHintergrund()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !liste.isEmpty {
                Menu {
                    Button("Alles löschen", systemImage: "trash", role: .destructive) { frageLoeschen = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Mehr")
            }
        }
        .confirmationDialog("Merkliste leeren?", isPresented: $frageLoeschen, titleVisibility: .visible) {
            Button(liste.count == 1 ? "Löschen" : "Alle \(liste.count) löschen", role: .destructive) {
                zustand.leereMerkliste()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(liste.count == 1
                 ? "Die Idee wird gelöscht. Das lässt sich nicht rückgängig machen."
                 : "Alle \(liste.count) Ideen werden gelöscht. Das lässt sich nicht rückgängig machen.")
        }
    }

    // MARK: Kopf

    private func kopf(_ liste: [MerkEintrag]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 10) {
                Text("merkliste").font(.titel(.largeTitle)).foregroundStyle(Look.text)
                // leer trägt das Auspack-Motiv; pro Ansicht nur ein Motiv (DESIGN.md 5)
                if !liste.isEmpty {
                    Image("coco-stapel").resizable().scaledToFit().frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
            }
            if !liste.isEmpty {
                Text(untertitel(liste)).font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
            }
        }
        .textCase(nil)
        .padding(.bottom, 4)
    }

    private func untertitel(_ liste: [MerkEintrag]) -> String {
        let ideen = liste.count
        let personen = Set(liste.map(\.fuer)).count
        let gekauft = liste.filter(\.gekauft).count
        var text = "\(ideen) \(ideen == 1 ? "Idee" : "Ideen") für \(personen) \(personen == 1 ? "Person" : "Personen")"
        if gekauft > 0 { text += ", \(gekauft) gekauft" }
        return text
    }

    private var umschalter: some View {
        Picker("Ordnen nach", selection: Binding(
            get: { ordnung },
            set: { neu in withAnimation(.easeOut(duration: 0.25)) { zustand.setzeMerkOrdnung(neu) } }
        )) {
            ForEach(MerkOrdnung.allCases) { Text($0.titel).tag($0) }
        }
        .auswahlStil()
        .labelsHidden()
    }

    private var leer: some View {
        VStack(spacing: 12) {
            Image("coco-geschenk").resizable().scaledToFit().frame(width: 160)
                .accessibilityHidden(true)
            Text("Noch nichts gemerkt. Was du beim Wischen nach rechts schiebst, landet hier.")
                .font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
                .multilineTextAlignment(.center)
            if let zumWischen {
                Button("Zum Wischen", action: zumWischen)
                    .font(.zuhause(.headline, .fett))
                    .foregroundStyle(Look.aufAkzent)
                    .padding(.horizontal, 24).frame(minHeight: 46)
                    .background(Look.akzent, in: Capsule())
                    .buttonStyle(.plain)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        // mittig im freien Raum statt oben unter dem Titel
        .containerRelativeFrame(.vertical, alignment: .center) { hoehe, _ in hoehe * 0.6 }
    }

    // MARK: Gruppen und Zeilen

    private func gruppenKopf(_ gruppe: MerkGruppe) -> some View {
        HStack {
            Text(ordnung == .person ? "für \(gruppe.titel)" : gruppe.titel)
                .font(.titel(.headline)).foregroundStyle(Look.text)
            Spacer(minLength: 8)
            if ordnung == .person, gruppe.eintraege.contains(where: { !$0.gekauft }) {
                ShareLink(item: teilText(fuer: gruppe.titel, eintraege: gruppe.eintraege)) {
                    Text("Teilen").font(.zuhause(.footnote, .fett)).foregroundStyle(Look.akzentText)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Ideen für \(gruppe.titel) teilen")
            }
        }
        // gleiche Höhe mit und ohne „Teilen“, sonst springt die Liste beim Umschalten
        .frame(minHeight: 44)
        .textCase(nil)
    }

    private func zeile(_ eintrag: MerkEintrag) -> some View {
        Button {
            if let url = eintrag.karte.sichererLink { oeffnen(url) }
        } label: {
            zeilenInhalt(eintrag)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                zustand.setzeGekauft(eintrag.id, !eintrag.gekauft)
            } label: {
                Label(eintrag.gekauft ? "Nicht gekauft" : "Gekauft",
                      systemImage: eintrag.gekauft ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(moosDunkel)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Löschen", systemImage: "trash", role: .destructive) { zustand.entferneMerk([eintrag.id]) }
        }
        .contextMenu {
            if let url = eintrag.karte.sichererLink {
                Button("Im Shop öffnen", systemImage: "arrow.up.right.square") { oeffnen(url) }
                ShareLink(item: url, subject: Text(eintrag.karte.titel)) {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
            }
            Button(eintrag.gekauft ? "Nicht mehr gekauft" : "Als gekauft abhaken",
                   systemImage: eintrag.gekauft ? "arrow.uturn.backward" : "checkmark") {
                zustand.setzeGekauft(eintrag.id, !eintrag.gekauft)
            }
            Button("Löschen", systemImage: "trash", role: .destructive) { zustand.entferneMerk([eintrag.id]) }
        }
        .accessibilityValue(eintrag.gekauft ? "gekauft" : "")
    }

    private func zeilenInhalt(_ eintrag: MerkEintrag) -> some View {
        let karte = eintrag.karte
        let neben = ordnung == .kategorie ? "für \(eintrag.fuer)" : karte.shop
        let text = VStack(alignment: .leading, spacing: 2) {
            Text(karte.titel).font(.zuhause(.subheadline, .halbfett))
                .foregroundStyle(eintrag.gekauft ? Look.leise : Look.text)
                .strikethrough(eintrag.gekauft, color: Look.leise)
                .lineLimit(schriftgroesse >= .xLarge ? nil : 3)
            (Text(karte.preisText).font(.zuhause(.footnote, .fett)).foregroundStyle(Look.preis)
                + Text(karte.versandHinweis.isEmpty ? "" : " \(karte.versandHinweis)").font(.zuhause(.footnote)).foregroundStyle(Look.leise)
                + Text(karte.preisText.isEmpty ? neben : " · \(neben)").font(.zuhause(.footnote)).foregroundStyle(Look.leise)
                // Partnerlink: auch in der Merkliste als Werbung erkennbar (§ 5a Abs. 4 UWG).
                + Text(karte.istAnzeige ? " · Anzeige" : "").font(.zuhause(.footnote)).foregroundStyle(Look.leise))
                .lineLimit(2)
        }
        return Group {
            if schriftgroesse.isAccessibilitySize {
                // sehr große Schrift: Foto über dem Text, damit der Titel die ganze Breite hat
                VStack(alignment: .leading, spacing: 8) {
                    foto(eintrag, groesse: 88)
                    text
                }
            } else {
                HStack(spacing: 12) {
                    foto(eintrag, groesse: 58)
                    text
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(Look.leise)
                }
            }
        }
        .frame(minHeight: 62)
        .contentShape(Rectangle())
    }

    private func foto(_ eintrag: MerkEintrag, groesse: CGFloat) -> some View {
        ZuhauseFoto(karte: eintrag.karte, ecken: 10)
            .opacity(eintrag.gekauft ? 0.55 : 1)
            .frame(width: groesse, height: groesse)
            .overlay(alignment: .bottomTrailing) {
                if eintrag.gekauft {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Look.hintergrund)
                        .frame(width: 20, height: 20)
                        .background(Look.palette.hell ? moosDunkel : moos, in: Circle())
                        .padding(4)
                        .accessibilityHidden(true)
                }
            }
    }

    /// Moosgrün aus der Palette (docs/design/palette-zuhause.md) für „gekauft“. Haken im
    /// Abendlicht: Espresso auf Moos (6,0); in Hell Grund auf Moosdunkel (4,57).
    private var moos: Color { Color(hex: 0x86A04B) }
    /// Wischaktion „Gekauft“: weiße Systemschrift braucht die dunkle Stufe (4,9 bzw. 5,6).
    private var moosDunkel: Color { Color(hex: Look.palette.hell ? 0x566F2D : 0x5F7A33) }
}
