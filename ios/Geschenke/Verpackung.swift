import SwiftUI

/// Geschenkverpackung über der Karte darunter. `offen`: Papier gleitet mit dem Zug zur Seite.
/// `auspacken`: Knoten löst sich, Anhänger fällt weg, Papier klappt nach hinten auf, das Licht
/// liegt zwischen Produkt und Papier und ist nur durch den Spalt zu sehen.
struct Verpackung: View, Animatable {
    var offen: Double
    var auspacken: Double
    let name: String
    let ruhig: Bool

    /// Die Einführung nutzt die Verpackung für ihre Übungskarte; der ausdrückliche
    /// Initialisierer macht diese Schnittstelle sichtbar.
    init(offen: Double, auspacken: Double, name: String, ruhig: Bool) {
        self.offen = offen
        self.auspacken = auspacken
        self.name = name
        self.ruhig = ruhig
    }

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(offen, auspacken) }
        set { offen = newValue.first; auspacken = newValue.second }
    }

    /// Ab hier ist das Papier hinter dem Kartenrand verschwunden; das Auspacken endet dort.
    static let ende = 0.66

    private let band: CGFloat = 30
    private let linie: CGFloat = 3.5
    private let ecke: CGFloat = 24
    private var linienFarbe: Color { Color(hex: Look.palette.hell ? 0x23160C : 0x7B5930) }
    private var rot: Color { Color(hex: Look.palette.hell ? 0xBE4A2E : 0xC9573A) }
    private var creme: Color { Look.creme }
    private let schaum = Color(hex: 0xD7BA81)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                licht.frame(width: w, height: h)
                tuer(links: true, w: w, h: h)
                tuer(links: false, w: w, h: h)
                // Anhänger unter dem Knoten: die Schnur verschwindet unter ihm
                anhaenger.position(x: w / 2, y: h / 2)
                knoten.position(x: w / 2, y: h / 2)
            }
        }
        // Weggeklappte und weggeschobene Papierhälften enden am Kartenrand
        .clipShape(RoundedRectangle(cornerRadius: ecke))
        .opacity(gesamt)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Werte je Zeitpunkt (wie bild(t) in der Demo)

    private var knotenWeg: Double {
        ruhig ? 0 : (auspacken > 0 ? aus(seg(auspacken, 0, 0.24)) : clamp(offen * 5))
    }
    private var winkel: Double { ruhig ? 0 : 104 * io(seg(auspacken, 0.14, 0.74)) }
    private var gesamt: Double {
        if ruhig { return 1 - max(offen, auspacken / Verpackung.ende) }
        if auspacken > 0 { return auspacken >= Verpackung.ende ? 0 : 1 }
        return offen < 0.8 ? 1 : (1 - offen) / 0.2
    }

    @ViewBuilder private var licht: some View {
        let staerke = ruhig ? 0 : 0.9 * sanft(seg(auspacken, 0.14, 0.32)) * (1 - sanft(seg(auspacken, 0.34, 0.54)))
        RadialGradient(stops: [
            .init(color: creme, location: 0),
            .init(color: Look.licht.opacity(0.9), location: 0.34),
            .init(color: Look.licht.opacity(0.4), location: 0.64),
            .init(color: Look.licht.opacity(0), location: 0.88),
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
                .frame(width: 13, height: 30).rotationEffect(.degrees(22), anchor: .top).offset(x: -10, y: 23)
            Schleifenende().fill(rot).overlay(Schleifenende().stroke(linienFarbe, lineWidth: linie))
                .frame(width: 13, height: 30).rotationEffect(.degrees(-22), anchor: .top).offset(x: 10, y: 23)
            // höher als das Band, sonst wirkt der Knoten wie ein flaches Siegel
            Ellipse().fill(rot).overlay(Ellipse().strokeBorder(linienFarbe, lineWidth: linie))
                .frame(width: 44, height: 36)
        }
        .scaleEffect(1 - k)
        .rotationEffect(.degrees(auspacken > 0 ? -25 * k : 0))
        .opacity(1 - k)
    }

    private var anhaenger: some View {
        let k = knotenWeg
        // Der Anhänger fällt nach unten weg und wird erst in der zweiten Hälfte durchsichtig
        let dx = 6 * k
        let dy = 64 * k
        let dreh = -7 + 18 * k
        return ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 12))
                p.addCurve(to: CGPoint(x: 0, y: 50), control1: CGPoint(x: 6, y: 22), control2: CGPoint(x: 2, y: 34))
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
        .opacity(1 - seg(k, 0.55, 1))
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
