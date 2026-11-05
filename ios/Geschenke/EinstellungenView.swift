import GeschenkeCore
import SwiftUI

/// Reiter „Einstellungen“: Erscheinung, Schriftgröße, Startbildschirm und Auspacken.
struct EinstellungenView: View {
    @EnvironmentObject private var zustand: AppZustand
    @AppStorage(Konfiguration.tokenSchluessel) private var token = ""
    @Environment(\.dynamicTypeSize) private var schriftgroesse
    @State private var zeigeEinfuehrung = false
    @State private var zeigeEinwilligung = false
    @State private var frageWiderruf = false
    @State private var frageLoeschen = false

    private struct Dokument: Identifiable {
        let id: String
        let titel: String
    }

    /// Feste Bezeichnungen: „Impressum“ muss als solches erkennbar sein (§ 5 DDG, KG Berlin).
    private static let dokumente = [
        Dokument(id: "impressum", titel: "Impressum"),
        Dokument(id: "datenschutz", titel: "Datenschutzerklärung"),
        Dokument(id: "nutzung", titel: "So entstehen die Vorschläge"),
        Dokument(id: "support", titel: "Hilfe und Kontakt"),
        Dokument(id: "lizenzen", titel: "Lizenzen"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Erscheinung", selection: Binding(
                        get: { Erscheinung.aus(zustand.daten.erscheinung) },
                        set: { zustand.setzeErscheinung($0) }
                    )) {
                        ForEach(Erscheinung.allCases) { Text($0.titel).tag($0) }
                    }
                    .auswahlStil()
                } header: {
                    kopf("Erscheinung")
                } footer: {
                    Text("Automatisch folgt dem Dunkelmodus des iPhones.")
                }
                .offeneZeilen()

                Section {
                    Picker("Schriftgröße", selection: Binding(
                        get: { Schriftstufe.aus(zustand.daten.schriftgroesse) },
                        set: { zustand.setzeSchrift($0) }
                    )) {
                        ForEach(Schriftstufe.allCases) { Text($0.titel).tag($0) }
                    }
                    .auswahlStil()
                    Text("So sieht Text in der App aus.").foregroundStyle(Look.leise)
                } header: {
                    kopf("Schriftgröße")
                }
                .offeneZeilen()

                geschenk

                Section {
                    Button { zeigeEinfuehrung = true } label: {
                        HStack {
                            Text("Einführung ansehen").foregroundStyle(Look.text)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(Look.leise)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .offeneZeilen()

                rechtliches

                // Im App-Store-Build steckt der Token immer drin; das Feld ist nur für Builds ohne Secret.
                if Konfiguration.tokenImBuild.isEmpty {
                    Section {
                        SecureField("Server-Token", text: $token)
                    } footer: {
                        Text("Nur nötig, wenn der Token nicht schon beim Bauen mitgegeben wurde.")
                    }
                    .offeneZeilen()
                }
            }
            .zuhauseHintergrund()
            .navigationTitle("Einstellungen")
            .fullScreenCover(isPresented: $zeigeEinfuehrung) {
                EinfuehrungView {
                    zustand.setzeEinfuehrungGesehen()
                    zeigeEinfuehrung = false
                }
            }
            .sheet(isPresented: $zeigeEinwilligung) {
                KiEinwilligungView { ja in
                    zeigeEinwilligung = false
                    if ja { zustand.setzeKiEinwilligung(true) }
                }
                .presentationBackground(Look.hintergrund)
            }
            .confirmationDialog("Zustimmung widerrufen?", isPresented: $frageWiderruf, titleVisibility: .visible) {
                Button("Widerrufen", role: .destructive) { zustand.setzeKiEinwilligung(false) }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Danach schickt die App nichts mehr an den Server und die KI. Gespräch und Vorschläge gehen erst wieder, wenn du erneut zustimmst.")
            }
            .confirmationDialog("Alle Daten löschen?", isPresented: $frageLoeschen, titleVisibility: .visible) {
                Button("Alles löschen", role: .destructive) { zustand.loescheAlles() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Deine Leute, die Merkliste, alles Gelernte und deine Einstellungen auf diesem iPhone werden gelöscht. Das lässt sich nicht rückgängig machen.")
            }
        }
    }

    /// Impressum in zwei Tippern (Reiter Einstellungen → Impressum), Zustimmung und Löschen.
    private var rechtliches: some View {
        Section {
            ForEach(Self.dokumente) { dokument in
                NavigationLink { RechtstextView(dokumentID: dokument.id) } label: {
                    Text(dokument.titel).foregroundStyle(Look.text)
                }
            }
            Button {
                if zustand.daten.hatKiEinwilligung { frageWiderruf = true } else { zeigeEinwilligung = true }
            } label: {
                Text(zustand.daten.hatKiEinwilligung ? "Zustimmung zur KI widerrufen" : "Zustimmung zur KI geben")
                    .foregroundStyle(Look.akzentText)
            }
            Button(role: .destructive) { frageLoeschen = true } label: {
                Text("Alle Daten löschen")
            }
        } header: {
            kopf("Datenschutz und Rechtliches")
        } footer: {
            Text(zustand.daten.hatKiEinwilligung
                 ? "Du hast zugestimmt, dass die App für Gespräch und Vorschläge Text an ihren Server und die KI schickt."
                 : "Ohne Zustimmung gehen Gespräch und Vorschläge nicht. Alles andere funktioniert.")
        }
        .offeneZeilen()
    }

    /// Startbildschirm und Auspacken.
    private var geschenk: some View {
        Section {
            Toggle(isOn: Binding(
                get: { zustand.daten.startTippen },
                set: { zustand.setzeStartTippen($0) }
            )) {
                HStack(spacing: 10) {
                    // Bei großer Schrift braucht der Text die Breite, sonst zerfällt er in drei Zeilen
                    if schriftgroesse < .xxLarge {
                        Image("coco-geschenk").resizable().scaledToFit().frame(width: 34, height: 34)
                            .accessibilityHidden(true)
                    }
                    Text("Zum Öffnen tippen")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Auspacken guter Treffer")
                Picker("Auspacken guter Treffer", selection: Binding(
                    get: { AuspackTempo.aus(zustand.daten.auspacken) },
                    set: { zustand.setzeAuspacken($0) }
                )) {
                    ForEach(AuspackTempo.allCases) { Text($0.titel).tag($0) }
                }
                .auswahlStil()
                .labelsHidden()
            }
            .padding(.vertical, 4)
        } header: {
            kopf("Geschenk")
        } footer: {
            Text("Ohne Tippen öffnet sich das Geschenk beim Start von selbst. Bei „aus“ verlieren auch gute Treffer ihre Verpackung nur mit dem Wischen.")
        }
        .offeneZeilen()
    }

    /// Abschnittsüberschrift ohne Großbuchstaben (DESIGN.md 3).
    private func kopf(_ text: String) -> some View {
        Text(text).font(.titel(.headline)).foregroundStyle(Look.text).textCase(nil)
    }
}
