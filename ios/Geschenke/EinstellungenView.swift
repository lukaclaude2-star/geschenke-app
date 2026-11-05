import GeschenkeCore
import SwiftUI

/// Reiter „Einstellungen“: Erscheinung, Schriftgröße, Startbildschirm und Auspacken.
struct EinstellungenView: View {
    @EnvironmentObject private var zustand: AppZustand
    @AppStorage(Konfiguration.tokenSchluessel) private var token = ""
    @Environment(\.dynamicTypeSize) private var schriftgroesse
    @State private var zeigeEinfuehrung = false

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

                Section {
                    SecureField("Server-Token", text: $token)
                } footer: {
                    Text("Nur nötig, wenn der Token nicht schon beim Bauen mitgegeben wurde.")
                }
                .offeneZeilen()
            }
            .zuhauseHintergrund()
            .navigationTitle("Einstellungen")
            .fullScreenCover(isPresented: $zeigeEinfuehrung) {
                EinfuehrungView { zeigeEinfuehrung = false }
            }
        }
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
