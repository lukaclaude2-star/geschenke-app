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

    var body: some View {
        if let eintrag = zustand.profil(profilID) {
            inhalt(eintrag)
        } else {
            Text("Profil nicht gefunden.").nachtblau()
        }
    }

    private func inhalt(_ eintrag: GespeichertesProfil) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(eintrag.profil.zusammenfassung).foregroundStyle(Look.leise)
                    FlussLayout(abstand: 6) {
                        ForEach(eintrag.profil.wuensche, id: \.tag) { Abzeichen(text: $0.label) }
                    }
                    if !eintrag.profil.ausschluesse.isEmpty {
                        Text("Nie: " + eintrag.profil.ausschluesse.map(\.label).joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(Look.leise)
                    }
                    if let budget = eintrag.profil.budgetMax {
                        Text("Budget: bis \(Int(budget)) €").font(.footnote).foregroundStyle(Look.leise)
                    }
                    Button("Geschenke wischen") {
                        ziel = WischZiel(name: eintrag.name, profil: eintrag.profil, profilID: eintrag.id,
                                         gewichtung: eintrag.gewichtung)
                    }
                    .buttonStyle(GoldKnopf())

                    Divider().overlay(Look.rand)
                    Text("Was hat sich geändert?").font(.headline)
                    ForEach(verlauf) { Blase(nachricht: $0) }
                    if denkt {
                        HStack(spacing: 8) {
                            ProgressView().tint(Look.gold)
                            if wachtAuf { Text("Server wacht auf …").foregroundStyle(Look.leise) }
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
                    Task { await aendern(eintrag) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }
                .disabled(denkt || anweisung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .nachtblau()
        .navigationTitle(eintrag.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $ziel) { WischView(ziel: $0) }
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
            let neu = try await zustand.api.profilAendern(eintrag.profil, anweisung: text)
            var gewichtung = eintrag.gewichtung
            gewichtung.uebernimm(profil: neu)
            zustand.aktualisiere(eintrag.id, profil: neu, gewichtung: gewichtung)
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
