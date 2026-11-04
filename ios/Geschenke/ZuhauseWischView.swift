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
    @State private var auspackID: String?
    @State private var auspackFortschritt: Double = 0
    @State private var ausgepackt: Set<String> = []
    @State private var trefferIDs: Set<String> = []
    @State private var bewertet: Set<String> = []
    @State private var entscheidungen = 0
    @State private var zeigeGelernt = false
    @State private var zeigeMerkliste = false
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
            if let karte = modell.stapel.first {
                HStack(spacing: 14) {
                    Button { weg(karte, ja: false) } label: {
                        Label("weiter", systemImage: "xmark")
                            .font(.zuhause(.headline, .fett)).foregroundStyle(Look.text)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Look.karte, in: Capsule())
                            .overlay(Capsule().stroke(Color(hex: Look.palette.hell ? 0x23160C : 0x7B5930).opacity(Look.palette.hell ? 0.25 : 1), lineWidth: 1))
                    }
                    Button { weg(karte, ja: true) } label: {
                        Label("merken", systemImage: "heart.fill")
                            .font(.zuhause(.headline, .fett)).foregroundStyle(Look.aufAkzent)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Look.akzent, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .nachtblau()
        .navigationTitle(modell.titel)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: entscheidungen)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
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
        .sheet(isPresented: $zeigeMerkliste) {
            NavigationStack {
                MerklisteView().toolbar { Button("Fertig") { zeigeMerkliste = false } }
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
            .offset(y: istOben ? 0 : 10 * (1 - folgt))
            .offset(istOben && !bewegungReduziert ? versatz : .zero)
            .rotationEffect(.degrees(istOben && !bewegungReduziert ? Double(versatz.width / 18) : 0))
            .opacity(deckkraft(rang: rang))
            .gesture(ziehen(eintrag), including: istOben ? .all : .none)
            .allowsHitTesting(istOben)
            .zIndex(Double(3 - rang))
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Merken") { weg(eintrag, ja: true) }
            .accessibilityAction(named: "Weiter") { weg(eintrag, ja: false) }
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
            Text("merken").font(.zuhause(.subheadline, .extrafett)).foregroundStyle(Look.aufAkzent)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Look.akzent, in: Capsule())
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
                ProgressView().tint(Look.akzent)
                Text(modell.wachtAuf ? "Server wacht auf …" : "Suche passende Geschenke …")
                    .font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
            } else if let fehler = modell.fehler {
                Text(fehler).font(.zuhause(.subheadline)).foregroundStyle(Look.leise).multilineTextAlignment(.center)
                Button("Nochmal") { Task { await modell.nachladen() } }.buttonStyle(RandKnopf())
            } else {
                Image("coco-geschenk").resizable().scaledToFit().frame(width: 120).accessibilityHidden(true)
                Text("Mehr passende Geschenke habe ich gerade nicht. Vielleicht schränken Budget oder Ausschlüsse stark ein. Ändere das im Profil oder die Gewichtung oben rechts.")
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

    private func ziehen(_ karte: StapelKarte) -> some Gesture {
        DragGesture()
            .onChanged {
                // Wer während des Auspackens zieht, will weiter: Auspacken sofort beenden.
                if auspackID != nil { auspackenBeenden() }
                versatz = CGSize(width: $0.translation.width, height: $0.translation.height * 0.3)
            }
            .onEnded { wert in
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
    private func weg(_ karte: StapelKarte, ja: Bool, fingerTempo: CGSize = .zero) {
        if auspackID != nil { auspackenBeenden() }
        guard wischt == nil, modell.stapel.first?.id == karte.id else { return }
        entscheidungen += 1
        let zielX: CGFloat = ja ? 560 : -560
        let rest = abs(zielX - versatz.width)
        let geschwindigkeit = max(abs(fingerTempo.width), 1300)
        let dauer = min(0.32, max(0.16, Double(rest / geschwindigkeit)))
        let zielY = versatz.height + 40 + min(120, max(-120, fingerTempo.height * 0.08))
        withAnimation(.easeOut(duration: dauer)) {
            wischt = karte.id
            versatz = CGSize(width: zielX, height: zielY)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dauer) {
            var ohneAnimation = Transaction()
            ohneAnimation.disablesAnimations = true
            withTransaction(ohneAnimation) {
                if ja { modell.ja(karte) } else { modell.nein(karte) }
                versatz = .zero
                wischt = nil
            }
        }
    }

    /// Liegt oben ein noch verpackter Treffer, packt er sich aus (nach Wischen, Laden, Umsortieren).
    private func obenPruefen(verzoegerung: Double) {
        guard let oben = modell.stapel.first, bleibtVerpackt(oben) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + verzoegerung) {
            guard auspackID == nil, wischt == nil, modell.stapel.first?.id == oben.id, bleibtVerpackt(oben) else { return }
            auspacken(oben)
        }
    }

    private func auspacken(_ karte: StapelKarte) {
        auspackID = karte.id
        auspackFortschritt = 0
        let dauer = tempo.dauer
        DispatchQueue.main.async {
            withAnimation(.linear(duration: dauer)) { auspackFortschritt = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dauer + 0.02) {
            if auspackID == karte.id { auspackenBeenden() }
        }
    }

    /// Schnelles Weiterwischen: Auspacken sofort zu Ende bringen statt es abzuwarten.
    private func auspackenBeenden() {
        guard let id = auspackID else { return }
        var ohneAnimation = Transaction()
        ohneAnimation.disablesAnimations = true
        withTransaction(ohneAnimation) {
            ausgepackt.insert(id)
            auspackFortschritt = 1
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
                .padding([.horizontal, .top], 12)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                if let fuer { Abzeichen(text: "für \(fuer)", gefuellt: true) }
                Text(karte.titel).font(.zuhause(.headline, .halbfett)).foregroundStyle(Look.text).lineLimit(2)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(karte.preisText).font(.zuhause(.subheadline, .extrafett)).foregroundStyle(Look.preis)
                    Text(karte.shop).font(.zuhause(.footnote)).foregroundStyle(Look.leise).lineLimit(1)
                }
                if istTreffer {
                    Text("passt besonders gut zu \(name)").font(.zuhause(.footnote, .fett)).foregroundStyle(Look.preis)
                } else if let grund {
                    Text(grund).font(.zuhause(.caption, .halbfett)).foregroundStyle(Look.text)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Color(hex: Look.palette.hell ? 0xE6D9C3 : 0x3A2516), in: Capsule())
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

/// Geschenkverpackung über der Karte darunter. `offen`: Papier gleitet mit dem Zug zur Seite.
/// `auspacken`: Knoten löst sich, Anhänger fällt weg, Papier klappt nach hinten auf, das Licht
/// liegt zwischen Produkt und Papier und ist nur durch den Spalt zu sehen.
struct Verpackung: View, Animatable {
    var offen: Double
    var auspacken: Double
    let name: String
    let ruhig: Bool

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(offen, auspacken) }
        set { offen = newValue.first; auspacken = newValue.second }
    }

    private let band: CGFloat = 30
    private let linie: CGFloat = 3.5
    private let ecke: CGFloat = 24
    private var linienFarbe: Color { Color(hex: Look.palette.hell ? 0x23160C : 0x7B5930) }
    private var rot: Color { Color(hex: Look.palette.hell ? 0xBE4A2E : 0xC9573A) }
    private let creme = Color(hex: 0xEBD9B4)
    private let schaum = Color(hex: 0xD7BA81)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                licht.frame(width: w, height: h)
                tuer(links: true, w: w, h: h)
                tuer(links: false, w: w, h: h)
                knoten.position(x: w / 2, y: h / 2)
                anhaenger.position(x: w / 2, y: h / 2)
            }
        }
        .opacity(gesamt)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Werte je Zeitpunkt (wie bild(t) in der Demo)

    private var knotenWeg: Double {
        ruhig ? 0 : (auspacken > 0 ? aus(seg(auspacken, 0, 0.24)) : clamp(offen * 1.6))
    }
    private var winkel: Double { ruhig ? 0 : 104 * io(seg(auspacken, 0.14, 0.74)) }
    private var gesamt: Double {
        if ruhig { return 1 - max(offen, auspacken) }
        if auspacken > 0 { return auspacken >= 1 ? 0 : 1 }
        return offen < 0.8 ? 1 : (1 - offen) / 0.2
    }

    @ViewBuilder private var licht: some View {
        let staerke = ruhig ? 0 : 0.9 * sanft(seg(auspacken, 0.14, 0.32)) * (1 - sanft(seg(auspacken, 0.34, 0.54)))
        RadialGradient(stops: [
            .init(color: creme, location: 0),
            .init(color: Color(hex: 0xEFB249).opacity(0.9), location: 0.34),
            .init(color: Color(hex: 0xEFB249).opacity(0.4), location: 0.64),
            .init(color: Color(hex: 0xEFB249).opacity(0), location: 0.88),
        ], center: .center, startRadius: 0, endRadius: 260)
        .scaleEffect(0.75 + 0.35 * seg(auspacken, 0.14, 0.54))
        .opacity(staerke)
        .clipShape(RoundedRectangle(cornerRadius: ecke))
    }

    private func tuer(links: Bool, w: CGFloat, h: CGFloat) -> some View {
        let breite = w / 2
        let form = UnevenRoundedRectangle(topLeadingRadius: links ? ecke : 0, bottomLeadingRadius: links ? ecke : 0,
                                          bottomTrailingRadius: links ? 0 : ecke, topTrailingRadius: links ? 0 : ecke)
        let rueckseite = winkel > 90
        let weggeschoben = CGFloat(ruhig ? 0 : offen) * breite
        return ZStack(alignment: links ? .trailing : .leading) {
            form.fill(rueckseite ? schaum : creme)
            if !rueckseite {
                // halbes senkrechtes Band an der Innenkante, waagerechtes Band auf halber Höhe
                Rectangle().fill(rot).frame(width: band / 2)
                    .overlay(alignment: links ? .leading : .trailing) {
                        Rectangle().fill(linienFarbe).frame(width: linie)
                    }
                VStack(spacing: 0) {
                    Rectangle().fill(linienFarbe).frame(height: linie)
                    Rectangle().fill(rot)
                    Rectangle().fill(linienFarbe).frame(height: linie)
                }
                .frame(height: band)
            }
            // doppelt so breit, weil die Form die äußere Hälfte abschneidet
            TuerUmriss(links: links, ecke: ecke).stroke(linienFarbe, lineWidth: linie * 2)
        }
        .frame(width: breite, height: h)
        .clipShape(form)
        .rotation3DEffect(.degrees(links ? winkel : -winkel), axis: (x: 0, y: 1, z: 0),
                          anchor: links ? .leading : .trailing, perspective: 0.75)
        .offset(x: links ? -weggeschoben : breite + weggeschoben)
        .opacity(1 - seg(auspacken, 0.74, 0.96))
    }

    private var knoten: some View {
        let k = knotenWeg
        return ZStack {
            Schleifenende().fill(rot).overlay(Schleifenende().stroke(linienFarbe, lineWidth: linie))
                .frame(width: 13, height: 30).rotationEffect(.degrees(22), anchor: .top).offset(x: -10, y: 19)
            Schleifenende().fill(rot).overlay(Schleifenende().stroke(linienFarbe, lineWidth: linie))
                .frame(width: 13, height: 30).rotationEffect(.degrees(-22), anchor: .top).offset(x: 10, y: 19)
            Ellipse().fill(rot).overlay(Ellipse().strokeBorder(linienFarbe, lineWidth: linie))
                .frame(width: 46, height: 30)
        }
        .scaleEffect(1 - k)
        .rotationEffect(.degrees(auspacken > 0 ? -25 * k : 0))
        .opacity(1 - k)
    }

    private var anhaenger: some View {
        let k = knotenWeg
        let dx = auspacken > 0 ? -24 * k : -30 * k
        let dy = auspacken > 0 ? -46 * k : -40 * k
        let dreh = auspacken > 0 ? -7 - 55 * k : -7 - 40 * k
        return ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 4))
                p.addCurve(to: CGPoint(x: 0, y: 50), control1: CGPoint(x: 6, y: 18), control2: CGPoint(x: 2, y: 32))
            }
            .stroke(linienFarbe, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            Text("für \(name)")
                .font(.zuhause(.footnote, .extrafett))
                .foregroundStyle(Color(hex: Look.palette.hell ? 0x23160C : 0x452C1B))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(width: 80)
                .padding(.top, 15).padding(.bottom, 8).padding(.horizontal, 8)
                .background(schaum, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(linienFarbe, lineWidth: linie))
                .overlay(alignment: .top) {
                    Circle().fill(Look.karte).overlay(Circle().strokeBorder(linienFarbe, lineWidth: 2))
                        .frame(width: 11, height: 11).padding(.top, 5)
                }
                .rotationEffect(.degrees(9), anchor: .top)
                .offset(x: -48, y: 44)
        }
        .frame(width: 0, height: 0, alignment: .topLeading)
        .rotationEffect(.degrees(dreh), anchor: .topLeading)
        .offset(x: dx, y: dy)
        .opacity(1 - k)
    }
}

/// Umriss einer Papierhälfte ohne die Innenkante (dort läuft das Band durch).
private struct TuerUmriss: Shape {
    let links: Bool
    let ecke: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        let e = min(ecke, r.width / 2, r.height / 2)
        if links {
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + e, y: r.minY))
            p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX, y: r.minY + e), radius: e)
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - e))
            p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX + e, y: r.maxY), radius: e)
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - e, y: r.minY))
            p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY + e), radius: e)
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - e))
            p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - e, y: r.maxY), radius: e)
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        }
        return p
    }
}

/// Bandende unter dem Knoten: oben offen, unten leicht gerundet.
private struct Schleifenende: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - 3))
        p.addQuadCurve(to: CGPoint(x: r.minX + 3, y: r.maxY), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - 3, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - 3), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

// Kurven wie in den Demos, ohne Federn
private func clamp(_ x: Double) -> Double { max(0, min(1, x)) }
private func seg(_ x: Double, _ a: Double, _ b: Double) -> Double { clamp((x - a) / (b - a)) }
private func io(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
private func aus(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
private func sanft(_ x: Double) -> Double { -(cos(Double.pi * x) - 1) / 2 }
