import GeschenkeCore
import SwiftUI

/// Ein gespeichertes Profil: direkt wischen oder per Chat ändern (Grundbaustein 8).
struct ProfilView: View {
    @EnvironmentObject private var zustand: AppZustand
    let profilID: UUID
    @State private var anweisung = ""
    @State private var verlauf: [ChatNachricht] = []
    @State private var denkt = false
    @State private var wachtAuf = false
    @State private var ziel: WischZiel?
    @State private var budgetVon = BudgetSkala.minimum
    @State private var budgetBis = BudgetSkala.maximum
    @State private var budgetGeaendert = false
    @State private var zeigeEinwilligung = false

    var body: some View {
        if let eintrag = zustand.profil(profilID) {
            inhalt(eintrag)
        } else {
            Text("Profil nicht gefunden.").zuhauseHintergrund()
        }
    }

    private func inhalt(_ eintrag: GespeichertesProfil) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(eintrag.profil.zusammenfassung).foregroundStyle(Look.leise)
                    FlussLayout(abstand: 6) {
                        ForEach(eintrag.profil.wuensche, id: \.tag) { Abzeichen(text: ohneEmoji($0.label)) }
                    }
                    if !eintrag.profil.ausschluesse.isEmpty {
                        Text("Nie: " + eintrag.profil.ausschluesse.map { ohneEmoji($0.label) }.joined(separator: ", "))
                            .font(.zuhause(.footnote))
                            .foregroundStyle(Look.leise)
                    }
                    GeburtstagZeile(geburtstag: eintrag.geburtstag) { zustand.setzeGeburtstag(profilID, $0) }
                    Button("Geschenke wischen") {
                        // Immer die aktuelle Fassung aus dem Speicher nehmen (inkl. Gesehen-Liste).
                        if let aktuell = zustand.profil(profilID) {
                            ziel = WischZiel(personen: [WischPerson(aktuell)])
                        }
                    }
                    .buttonStyle(GoldKnopf())

                    VStack(alignment: .leading, spacing: 10) {
                        Abschnittstitel(text: "Budget")
                        BudgetRegler(von: $budgetVon, bis: $budgetBis)
                            .onChange(of: budgetVon) { budgetGeaendert = true }
                            .onChange(of: budgetBis) { budgetGeaendert = true }
                        if budgetGeaendert {
                            Button("Budget übernehmen") { budgetUebernehmen() }
                                .buttonStyle(RandKnopf())
                        }
                    }
                    .padding(.vertical, 4)

                    Look.trenner
                    Abschnittstitel(text: "Was hat sich geändert?")
                    ForEach(verlauf) { Blase(nachricht: $0) }
                    if denkt {
                        HStack(spacing: 8) {
                            ProgressView().tint(Look.akzentText)
                            if wachtAuf { Text(wachtAufText).foregroundStyle(Look.leise) }
                        }
                    }
                }
                .padding()
            }
            HStack(spacing: 8) {
                TextField("", text: $anweisung,
                          prompt: Text("z. B. sie hat jetzt einen Hund").foregroundStyle(Look.leise), axis: .vertical)
                    .lineLimit(1...3)
                    .padding(10)
                    .background(Look.karte)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button {
                    // Die Änderung geht an die KI: ohne Zustimmung erst fragen.
                    if zustand.daten.hatKiEinwilligung {
                        Task { await aendern(eintrag) }
                    } else {
                        zeigeEinwilligung = true
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }
                .disabled(denkt || anweisung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .sheet(isPresented: $zeigeEinwilligung) {
            KiEinwilligungView { ja in
                zeigeEinwilligung = false
                guard ja else { return }
                zustand.setzeKiEinwilligung(true)
                Task { await aendern(eintrag) }
            }
            .presentationBackground(Look.hintergrund)
        }
        .zuhauseHintergrund()
        .navigationTitle(eintrag.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $ziel) { WischZielView(ziel: $0) }
        .onAppear { budgetLaden() }
    }

    private func budgetLaden() {
        guard let profil = zustand.profil(profilID)?.profil else { return }
        // Geklemmt: z. B. „ab 500 €“ würde sonst beide Griffe übereinanderlegen.
        let start = BudgetSkala.startwerte(min: profil.budgetMin, max: profil.budgetMax)
        budgetVon = start.von
        budgetBis = start.bis
        DispatchQueue.main.async { budgetGeaendert = false }
    }

    private func budgetUebernehmen() {
        guard var profil = zustand.profil(profilID)?.profil else { return }
        let grenzen = BudgetSkala.grenzen(von: budgetVon, bis: budgetBis)
        profil.budgetMin = grenzen.min
        profil.budgetMax = grenzen.max
        zustand.aktualisiere(profilID, profil: profil)
        budgetGeaendert = false
    }

    private func aendern(_ eintrag: GespeichertesProfil) async {
        let text = anweisung.trimmingCharacters(in: .whitespacesAndNewlines)
        anweisung = ""
        verlauf.append(ChatNachricht(rolle: "nutzer", text: text))
        denkt = true
        let hinweis = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { wachtAuf = true }
        }
        defer {
            hinweis.cancel()
            wachtAuf = false
        }
        do {
            // Aktuelle Fassung lesen: das Wischen kann Gelerntes gespeichert haben, seit die Ansicht offen ist.
            let aktuell = zustand.profil(eintrag.id) ?? eintrag
            let neu = try await zustand.api.profilAendern(aktuell.profil, anweisung: text)
            var gewichtung = zustand.profil(eintrag.id)?.gewichtung ?? aktuell.gewichtung
            gewichtung.uebernimm(profil: neu)
            zustand.aktualisiere(eintrag.id, profil: neu, gewichtung: gewichtung)
            budgetLaden()
            verlauf.append(ChatNachricht(rolle: "app", text: "Erledigt! \(neu.zusammenfassung)"))
        } catch {
            verlauf.append(ChatNachricht(rolle: "app", text: fehlerText(error) + " Deine Nachricht steht wieder im Feld."))
            anweisung = text
        }
        denkt = false
    }
}

/// Bricht Abzeichen in mehrere Zeilen um.
struct FlussLayout: Layout {
    var abstand: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let breite = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, zeile: CGFloat = 0
        for teil in subviews {
            let groesse = teil.sizeThatFits(.unspecified)
            if x + groesse.width > breite, x > 0 {
                x = 0
                y += zeile + abstand
                zeile = 0
            }
            x += groesse.width + abstand
            zeile = max(zeile, groesse.height)
        }
        return CGSize(width: breite == .infinity ? x : breite, height: y + zeile)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, zeile: CGFloat = 0
        for teil in subviews {
            let groesse = teil.sizeThatFits(.unspecified)
            if x + groesse.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += zeile + abstand
                zeile = 0
            }
            teil.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(groesse))
            x += groesse.width + abstand
            zeile = max(zeile, groesse.height)
        }
    }
}

/// Freiwilliger Geburtstag (nur Tag und Monat) für den Countdown auf der Startseite.
struct GeburtstagZeile: View {
    let geburtstag: Geburtstag?
    let aendern: (Geburtstag?) -> Void

    private static let monate = ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni",
                                 "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."]
    private static let tageImMonat = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    var body: some View {
        HStack(spacing: 8) {
            Text("Geburtstag").font(.zuhause(.headline, .halbfett))
            Spacer()
            if let g = geburtstag {
                Picker("Tag", selection: Binding(
                    get: { g.tag },
                    set: { aendern(Geburtstag(tag: $0, monat: g.monat)) }
                )) {
                    // Monat abgesichert, damit kaputte gespeicherte Daten nicht abstürzen lassen.
                    ForEach(1...Self.tageImMonat[min(max(g.monat, 1), 12) - 1], id: \.self) { Text("\($0).").tag($0) }
                }
                Picker("Monat", selection: Binding(
                    get: { g.monat },
                    set: { aendern(Geburtstag(tag: min(g.tag, Self.tageImMonat[$0 - 1]), monat: $0)) }
                )) {
                    ForEach(1...12, id: \.self) { Text(Self.monate[$0 - 1]).tag($0) }
                }
                Button {
                    aendern(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Look.leise)
                }
                .accessibilityLabel("Geburtstag entfernen")
            } else {
                Button("Eintragen") {
                    let heute = Calendar.current.dateComponents([.day, .month], from: Date())
                    aendern(Geburtstag(tag: heute.day ?? 1, monat: heute.month ?? 1))
                }
                .foregroundStyle(Look.akzentText)
            }
        }
        .pickerStyle(.menu)
        .padding(.vertical, 4)
    }
}
