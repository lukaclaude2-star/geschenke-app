import GeschenkeCore
import SwiftUI

/// Wischen im Zuhause-Stil (DESIGN.md 6b): Die Karte darunter ist verpackt und öffnet sich mit
/// dem Zug. Richtig gute Treffer (beste 10 % nach Stichwörtern, nie nach Provision) bleiben
/// verpackt und packen sich aus, sobald sie oben liegen. Vorlage: Demo `2026-11-05-wischkarte-2`.
struct ZuhauseWischView: View {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.accessibilityReduceMotion) private var bewegungReduziert
    @ObservedObject var modell: KartenStapelModell
    @State private var versatz: CGSize = .zero
    @State private var wischt: String?
    @State private var flugJa = false
    @State private var auspackID: String?
    @State private var auspackFortschritt: Double = 0
    @State private var ausgepackt: Set<String> = []
    @State private var trefferIDs: Set<String> = []
    @State private var bewertet: Set<String> = []
    @State private var entscheidungen = 0
    @State private var zeigeGelernt = false
    @State private var zeigeMerkliste = false
    @State private var zeigeSoEntstehen = false
    @State private var gewichteBeimOeffnen: [Gewichtung] = []
    private let schwelle: CGFloat = 110

    private var tempo: AuspackTempo { AuspackTempo.aus(zustand.daten.auspacken) }
    private var zug: CGFloat { min(1, abs(versatz.width) / schwelle) }

    var body: some View {
        VStack(spacing: 12) {
            if let hinweis = modell.duennHinweis {
                Text(hinweis).font(.zuhause(.footnote, .halbfett)).foregroundStyle(Look.preis)
            }
            ZStack {
                if modell.stapel.isEmpty { leer }
                // Drei Karten: die dritte liegt unsichtbar bereit und blendet beim Wegwerfen ein
                let oben = Array(modell.stapel.prefix(3))
                ForEach(oben.reversed()) { eintrag in
                    karte(eintrag, rang: oben.firstIndex(of: eintrag) ?? 0)
                }
            }
            .frame(maxHeight: .infinity)
            // Platz für das herausschauende Geschenk, damit es nicht an den Knöpfen klebt
            .padding(.bottom, 14)
            // Die Geste hängt am Stapel: Wer während Flug oder Auspacken zieht, übernimmt sofort
            // die nächste Karte (am einzelnen Kartenblatt ginge die Geste beim Wechsel verloren).
            .contentShape(Rectangle())
            .gesture(ziehen, including: modell.stapel.isEmpty ? .none : .all)
            if !modell.stapel.isEmpty {
                HStack(spacing: 14) {
                    Button { wegOben(ja: false) } label: {
                        Label("weiter", systemImage: "xmark")
                            .font(.zuhause(.headline, .fett)).foregroundStyle(Look.text)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Look.karte, in: Capsule())
                            .overlay(Capsule().stroke(Look.linie, lineWidth: 1))
                    }
                    Button { wegOben(ja: true) } label: {
                        Label("merken", systemImage: "heart.fill")
                            .font(.zuhause(.headline, .fett)).foregroundStyle(Look.aufFokus)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Look.fokus, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zuhauseHintergrund()
        .navigationTitle(modell.titel)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: entscheidungen)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // § 5b Abs. 2 UWG: Hauptkriterien der Reihenfolge direkt bei den Ergebnissen.
                Button { zeigeSoEntstehen = true } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel("So entstehen die Vorschläge")
                Button { modell.zurueck() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!modell.kannZurueck || wischt != nil)
                    .accessibilityLabel("Zurück")
                Button {
                    gewichteBeimOeffnen = modell.personen.map(\.gewichtung)
                    zeigeGelernt = true
                } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Was ich gelernt habe")
                Button { zeigeMerkliste = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.text.square")
                        Text("\(zustand.daten.merkliste.count)").font(.footnote.monospacedDigit())
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeGelernt, onDismiss: {
            modell.sichernJetzt()
            if modell.personen.map(\.gewichtung) != gewichteBeimOeffnen {
                Task { await modell.neuSortieren() }
            }
        }) {
            GelerntView(modell: modell)
        }
        .sheet(isPresented: $zeigeSoEntstehen) { RechtstextBlatt(dokumentID: "nutzung") }
        .sheet(isPresented: $zeigeMerkliste) {
            NavigationStack {
                MerklisteView(zumWischen: { zeigeMerkliste = false })
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Fertig") { zeigeMerkliste = false } } }
            }
            .presentationBackground(Look.hintergrund)
        }
        .onChange(of: modell.stapel.map(\.id)) { alt, _ in
            bewerteNeue()
            // Beim ersten Laden packt sich ein Treffer zur Begrüßung etwas verzögert aus.
            obenPruefen(verzoegerung: alt.isEmpty ? 0.35 : 0)
        }
        .task {
            modell.verbinde(zustand)
            if modell.stapel.isEmpty { await modell.nachladen() }
            bewerteNeue()
            obenPruefen(verzoegerung: 0.35)
        }
    }

    // MARK: Karte

    @ViewBuilder private func karte(_ eintrag: StapelKarte, rang: Int) -> some View {
        let person = modell.personen[eintrag.person]
        let istOben = rang == 0
        let folgt: CGFloat = rang == 1 ? zug : 0
        ZuhauseKarte(karte: eintrag.karte,
                     grund: passtWeil(eintrag.karte, gewichtung: person.gewichtung),
                     istTreffer: trefferIDs.contains(eintrag.id),
                     name: person.name ?? "diese Person",
                     fuer: modell.istSammel ? modell.name(eintrag.person) : nil)
            .overlay { verpackung(eintrag, rang: rang, name: person.name) }
            .overlay(alignment: .top) { if istOben { stempel } }
            .scaleEffect(istOben ? 1 : 0.96 + 0.04 * folgt)
            .offset(y: istOben ? 0 : 20 * (1 - folgt))
            .offset(istOben && !bewegungReduziert ? versatz : .zero)
            .rotationEffect(.degrees(istOben && !bewegungReduziert ? Double(versatz.width / 18) : 0))
            .opacity(deckkraft(rang: rang))
            .allowsHitTesting(istOben)
            .zIndex(Double(3 - rang))
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Merken") { wegOben(ja: true) }
            .accessibilityAction(named: "Weiter") { wegOben(ja: false) }
    }

    private func deckkraft(rang: Int) -> Double {
        switch rang {
        case 0: return bewegungReduziert && wischt != nil ? 0 : 1
        case 1: return 1
        default: return wischt != nil ? 1 : 0
        }
    }

    @ViewBuilder private func verpackung(_ eintrag: StapelKarte, rang: Int, name: String?) -> some View {
        let anhaenger = name ?? (modell.istSammel ? modell.name(eintrag.person) : "dich")
        if rang == 0 {
            if auspackID == eintrag.id {
                Verpackung(offen: 0, auspacken: auspackFortschritt, name: anhaenger, ruhig: bewegungReduziert)
            } else if bleibtVerpackt(eintrag) {
                Verpackung(offen: 0, auspacken: 0, name: anhaenger, ruhig: bewegungReduziert)
            }
        } else if rang == 2 || bleibtVerpackt(eintrag) {
            Verpackung(offen: 0, auspacken: 0, name: anhaenger, ruhig: bewegungReduziert)
        } else {
            Verpackung(offen: Double(zug), auspacken: 0, name: anhaenger, ruhig: bewegungReduziert)
        }
    }

    @ViewBuilder private var stempel: some View {
        HStack {
            Text("merken").font(.zuhause(.subheadline, .extrafett)).foregroundStyle(Look.aufFokus)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Look.fokus, in: Capsule())
                .opacity(Double(max(0, versatz.width / 90)))
            Spacer()
            Text("weiter").font(.zuhause(.subheadline, .extrafett)).foregroundStyle(Look.text)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Look.karte, in: Capsule())
                .opacity(Double(max(0, -versatz.width / 90)))
        }
        .padding(20)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var leer: some View {
        VStack(spacing: 12) {
            if modell.laedt {
                ProgressView().tint(Look.akzentText)
                Text(modell.wachtAuf ? wachtAufText : "Suche passende Geschenke …")
                    .font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
            } else if let fehler = modell.fehler {
                Text(fehler).font(.zuhause(.subheadline)).foregroundStyle(Look.leise).multilineTextAlignment(.center)
                Button("Nochmal versuchen") { Task { await modell.nachladen() } }.buttonStyle(RandKnopf())
            } else {
                Image("coco-geschenk").resizable().scaledToFit().frame(width: 120).accessibilityHidden(true)
                Text("Mehr passende Geschenke habe ich gerade nicht. Lockere Budget oder Ausschlüsse im Profil oder ändere die Gewichtung oben rechts.")
                    .font(.zuhause(.subheadline)).foregroundStyle(Look.leise).multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: Ablauf

    private func bleibtVerpackt(_ eintrag: StapelKarte) -> Bool {
        tempo.dauer > 0 && trefferIDs.contains(eintrag.id) && !ausgepackt.contains(eintrag.id)
    }

    /// Entscheidet für neu geladene Karten einmal, ob sie richtig gute Treffer sind, damit sich
    /// die Auswahl beim Wegwischen nicht nach und nach verschiebt.
    private func bewerteNeue() {
        let neue = Set(modell.stapel.map(\.id)).subtracting(bewertet)
        guard !neue.isEmpty else { return }
        var treffer = Set<String>()
        for (nummer, person) in modell.personen.enumerated() {
            let karten = modell.stapel.filter { $0.person == nummer }.map(\.karte)
            treffer.formUnion(richtigGuteTreffer(karten, gewichtung: person.gewichtung))
        }
        trefferIDs.formUnion(treffer.intersection(neue))
        bewertet.formUnion(neue)
    }

    private var ziehen: some Gesture {
        DragGesture()
            .onChanged {
                // Wer während Flug oder Auspacken zieht, will weiter: alles sofort zu Ende bringen
                allesBeenden()
                versatz = CGSize(width: $0.translation.width, height: $0.translation.height * 0.3)
            }
            .onEnded { wert in
                guard let karte = modell.stapel.first, wischt == nil else { return }
                let weit = wert.translation.width
                let schwung = wert.predictedEndTranslation.width
                if weit > schwelle || schwung > schwelle * 2.6 {
                    weg(karte, ja: true, fingerTempo: wert.velocity)
                } else if weit < -schwelle || schwung < -schwelle * 2.6 {
                    weg(karte, ja: false, fingerTempo: wert.velocity)
                } else {
                    // nicht weit genug: Karte und Verpackung gleiten im selben Takt zurück
                    withAnimation(.easeOut(duration: 0.22)) { versatz = .zero }
                }
            }
    }

    /// `fingerTempo`: Fingergeschwindigkeit beim Loslassen (pt/s), damit die Karte mit dem Schwung
    /// weiterfliegt statt abzubremsen. Knöpfe werfen mit einem ruhigen Standardtempo.
    /// Knöpfe und Bedienungshilfen: Ein zweiter Druck während Flug oder Auspacken wirft gleich
    /// die nächste Karte, statt verschluckt zu werden.
    private func wegOben(ja: Bool) {
        allesBeenden()
        guard let karte = modell.stapel.first else { return }
        weg(karte, ja: ja)
    }

    /// Bringt laufenden Flug und laufendes Auspacken sofort ans Ende; ein Treffer, der oben liegt
    /// und noch gar nicht angefangen hat, verliert seine Verpackung ohne Ablauf.
    private func allesBeenden() {
        flugAbschliessen()
        auspackenBeenden()
        if let oben = modell.stapel.first, bleibtVerpackt(oben) { ausgepackt.insert(oben.id) }
    }

    private func weg(_ karte: StapelKarte, ja: Bool, fingerTempo: CGSize = .zero) {
        guard wischt == nil, modell.stapel.first?.id == karte.id else { return }
        if bleibtVerpackt(karte) { ausgepackt.insert(karte.id) }
        entscheidungen += 1
        let zielX: CGFloat = ja ? 560 : -560
        let rest = abs(zielX - versatz.width)
        let geschwindigkeit = max(abs(fingerTempo.width), 1300)
        // Routine höchstens 300 ms (DESIGN.md 6)
        let dauer = min(0.28, max(0.16, Double(rest / geschwindigkeit)))
        let zielY = versatz.height + 40 + min(120, max(-120, fingerTempo.height * 0.08))
        flugJa = ja
        withAnimation(.easeOut(duration: dauer)) {
            wischt = karte.id
            versatz = CGSize(width: zielX, height: zielY)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dauer) {
            if wischt == karte.id { flugAbschliessen() }
        }
    }

    private func flugAbschliessen() {
        guard let id = wischt else { return }
        ohneAnimation {
            if let karte = modell.stapel.first, karte.id == id {
                if flugJa { modell.ja(karte) } else { modell.nein(karte) }
            }
            versatz = .zero
            wischt = nil
        }
    }

    /// Liegt oben ein noch verpackter Treffer, packt er sich aus (nach Wischen, Laden, Umsortieren).
    private func obenPruefen(verzoegerung: Double) {
        guard let oben = modell.stapel.first, bleibtVerpackt(oben) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + verzoegerung) {
            guard auspackID == nil, wischt == nil, versatz == .zero, modell.stapel.first?.id == oben.id,
                  bleibtVerpackt(oben) else { return }
            auspacken(oben)
        }
    }

    private func auspacken(_ karte: StapelKarte) {
        auspackID = karte.id
        auspackFortschritt = 0
        // Kurven wie in der Demo über die volle Dauer, aber ab 0,66 ist das Papier schon hinter
        // dem Kartenrand: dort aufhören statt stillzustehen.
        let dauer = tempo.dauer * Verpackung.ende
        DispatchQueue.main.async {
            withAnimation(.linear(duration: dauer)) { auspackFortschritt = Verpackung.ende }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dauer + 0.02) {
            if auspackID == karte.id { auspackenBeenden() }
        }
    }

    /// Schnelles Weiterwischen: Auspacken sofort zu Ende bringen statt es abzuwarten.
    private func auspackenBeenden() {
        guard let id = auspackID else { return }
        ohneAnimation {
            ausgepackt.insert(id)
            auspackFortschritt = Verpackung.ende
            auspackID = nil
        }
    }
}

/// Produktkarte im Zuhause-Stil: Foto auf Creme, Titel, Preis und Shop, darunter warum sie passt.
struct ZuhauseKarte: View {
    let karte: Karte
    let grund: String?
    let istTreffer: Bool
    let name: String
    var fuer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZuhauseFoto(karte: karte, ecken: 16)
                .overlay(alignment: .topLeading) {
                    if karte.istIdee { Abzeichen(text: "Idee", gefuellt: true).padding(10) }
                }
                // Partnerlink: als Werbung erkennbar direkt an der Karte (§ 5a Abs. 4 UWG).
                .overlay(alignment: .topTrailing) {
                    if karte.istAnzeige { Abzeichen(text: "Anzeige").padding(10) }
                }
                .padding([.horizontal, .top], 12)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                if let fuer { Abzeichen(text: "für \(fuer)", gefuellt: true) }
                Text(karte.titel).font(.zuhause(.headline, .halbfett)).foregroundStyle(Look.text).lineLimit(2)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(karte.preisText).font(.zuhause(.subheadline, .extrafett)).foregroundStyle(Look.preis)
                    if !karte.versandHinweis.isEmpty {
                        Text(karte.versandHinweis).font(.zuhause(.caption)).foregroundStyle(Look.leise).fixedSize()
                    }
                    Text(karte.shop).font(.zuhause(.footnote)).foregroundStyle(Look.leise).lineLimit(1)
                }
                if istTreffer {
                    Text("passt besonders gut zu \(name)").font(.zuhause(.footnote, .fett)).foregroundStyle(Look.fokusText)
                } else if let grund {
                    Text(grund).font(.zuhause(.caption, .halbfett)).foregroundStyle(Look.text)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Look.flaeche, in: Capsule())
                        .overlay(Capsule().stroke(Color(hex: Look.palette.hell ? 0xE0D0B5 : 0x7B5930), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zuhauseKarte(ecken: 24)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
