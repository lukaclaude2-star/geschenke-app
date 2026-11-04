import AVFoundation
import GeschenkeCore
import SwiftUI

/// Startbildschirm im Zuhause-Stil (DESIGN.md 6a): Geschenk-Logo mit Ladering, der sich füllt,
/// während der Server aufwacht. Tippen (oder automatisch) spielt die freigegebene Animation als
/// Video bis zur vollen Lichtflut; danach zieht sich das Licht nativ zur Lichtinsel zusammen,
/// während darunter schon die Startseite liegt.
struct StartBildschirm: View {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.accessibilityReduceMotion) private var bewegungReduziert
    let fertig: () -> Void

    @StateObject private var video = StartVideo()
    @State private var fortschritt: Double = 0
    @State private var bereit = false
    @State private var laeuft = false
    @State private var lichtZurueck = false
    @State private var lichtZurueckFortschritt = false
    @State private var weg = false

    /// Maße aus der Demo `2026-11-05-startanimation-2` (Video 390 × 844, Logo bei 45 % Höhe).
    private static let videoGroesse = CGSize(width: 390, height: 844)
    private static let logoHoehe: CGFloat = 0.45
    private static let ringRadius: CGFloat = 154

    var body: some View {
        GeometryReader { geo in
            let s = max(geo.size.width / Self.videoGroesse.width, geo.size.height / Self.videoGroesse.height)
            // Mitte des Logos auf dem Bildschirm, wenn das Video den Bildschirm füllt (Aspect-Fill)
            let mitte = CGPoint(x: geo.size.width / 2,
                                y: geo.size.height / 2 + (Self.logoHoehe - 0.5) * Self.videoGroesse.height * s)
            ZStack {
                if !lichtZurueck {
                    Look.hintergrund
                    // Erstes Bild des Videos als Standbild, bis der Spieler sein erstes Bild zeigt
                    Image(Look.palette.hell ? "start-hell-bild" : "start-abend-bild")
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                    StartVideoFlaeche(spieler: video.spieler)
                    ring(s: s).position(mitte).opacity(laeuft ? 0 : 1)
                    hinweis.position(x: mitte.x, y: mitte.y + (Self.ringRadius + 30) * s).opacity(laeuft ? 0 : 1)
                } else {
                    lichtFlut(s: s, mitte: mitte)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .opacity(weg ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { getippt() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bereit ? "Geschenk öffnen" : "Einen Moment, der Server wacht auf")
        .accessibilityAddTraits(.isButton)
        .task { await aufwecken() }
        .onAppear { video.laden(hell: Look.palette.hell) }
    }

    private func ring(s: CGFloat) -> some View {
        let durchmesser = Self.ringRadius * 2 * s
        return ZStack {
            Circle().stroke(Look.karte, lineWidth: 4 * s)
            Circle().trim(from: 0, to: fortschritt)
                .stroke(Color(hex: Look.palette.hell ? 0xD7BA81 : 0xEBD9B4),
                        style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: durchmesser, height: durchmesser)
    }

    @ViewBuilder private var hinweis: some View {
        if bereit && zustand.daten.startTippen {
            Text("zum Öffnen tippen").font(.subheadline.weight(.semibold)).foregroundStyle(Look.text)
        } else if !bereit {
            Text("einen Moment …").font(.subheadline).foregroundStyle(Look.leise)
        }
    }

    /// Nach dem Video: volle Flut in Creme, die sich nach oben links zur Lichtinsel zusammenzieht.
    private func lichtFlut(s: CGFloat, mitte: CGPoint) -> some View {
        ZStack {
            Color(hex: 0xEBD9B4).opacity(lichtZurueckFortschritt ? 0 : 1)
                .animation(.easeOut(duration: 0.45), value: lichtZurueckFortschritt)
            RadialGradient(stops: [
                .init(color: Color(hex: 0xEBD9B4), location: 0),
                .init(color: Color(hex: 0xEBD9B4), location: 0.2),
                .init(color: Color(hex: 0xEFB249), location: 0.43),
                .init(color: Color(hex: 0xEFB249).opacity(0.55), location: 0.66),
                .init(color: Color(hex: 0xEFB249).opacity(0.15), location: 0.86),
                .init(color: Color(hex: 0xEFB249).opacity(0), location: 1),
            ], center: .center, startRadius: 0, endRadius: 315 * s)
            .frame(width: 630 * s, height: 630 * s)
            .scaleEffect(lichtZurueckFortschritt ? 0.5 : 3.08)
            .opacity(lichtZurueckFortschritt ? 0 : 1)
            .position(x: mitte.x + (lichtZurueckFortschritt ? -112 * s : 0),
                      y: mitte.y + (lichtZurueckFortschritt ? -262 * s : 0))
            .animation(.timingCurve(0.65, 0, 0.35, 1, duration: 1.05), value: lichtZurueckFortschritt)
        }
        .allowsHitTesting(false)
    }

    private func aufwecken() async {
        // Erst schnell, dann zäh: echtes Laden, aber ohne bekannte Dauer
        withAnimation(.timingCurve(0.25, 0.8, 0.35, 1, duration: 20)) { fortschritt = 0.9 }
        await withTaskGroup(of: Void.self) { gruppe in
            gruppe.addTask { _ = await StartVideo.serverWach() }
            // Antwortet der Server nicht, darf man nach 25 s trotzdem öffnen (die App zeigt dann ihre Fehler)
            gruppe.addTask { _ = try? await Task.sleep(for: .seconds(25)) }
            await gruppe.next()
            gruppe.cancelAll()
        }
        withAnimation(.easeOut(duration: 0.35)) { fortschritt = 1 }
        try? await Task.sleep(for: .seconds(0.35))
        bereit = true
        if !zustand.daten.startTippen {
            try? await Task.sleep(for: .seconds(0.35))
            oeffnen()
        }
    }

    private func getippt() {
        if laeuft { ueberspringen() } else { oeffnen() }
    }

    private func oeffnen() {
        guard bereit, !laeuft else { return }
        laeuft = true
        if bewegungReduziert || !video.vorhanden {
            withAnimation(.easeInOut(duration: 0.5)) { weg = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { fertig() }
            return
        }
        video.abspielen {
            lichtZurueck = true
            DispatchQueue.main.async { lichtZurueckFortschritt = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { fertig() }
        }
    }

    /// Zweites Tippen: sofort zur Startseite.
    private func ueberspringen() {
        video.anhalten()
        withAnimation(.easeOut(duration: 0.25)) { weg = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { fertig() }
    }
}

/// Spielt `start-abend.mp4` bzw. `start-hell.mp4` aus dem Bundle, ohne Ton.
@MainActor
final class StartVideo: ObservableObject {
    let spieler = AVPlayer()
    private(set) var vorhanden = false
    private var ende: NSObjectProtocol?

    func laden(hell: Bool) {
        guard spieler.currentItem == nil,
              let url = Bundle.main.url(forResource: hell ? "start-hell" : "start-abend", withExtension: "mp4") else { return }
        // Ambient: das Video hat keinen Ton und soll keine laufende Musik anhalten
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        spieler.isMuted = true
        spieler.replaceCurrentItem(with: AVPlayerItem(url: url))
        vorhanden = true
    }

    func abspielen(danach: @escaping () -> Void) {
        ende = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                      object: spieler.currentItem, queue: .main) { _ in
            MainActor.assumeIsolated { danach() }
        }
        spieler.play()
    }

    func anhalten() {
        spieler.pause()
        if let ende { NotificationCenter.default.removeObserver(ende) }
    }

    /// Weckt den Render-Server (schläft nach 15 Minuten) und wartet auf seine Antwort.
    nonisolated static func serverWach() async -> Bool {
        var anfrage = URLRequest(url: Konfiguration.serverURL.appendingPathComponent("health"),
                                 timeoutInterval: GeschenkeAPI.zeitlimit)
        anfrage.httpMethod = "GET"
        guard let ergebnis = try? await URLSession.shared.data(for: anfrage) else { return false }
        return (ergebnis.1 as? HTTPURLResponse)?.statusCode == 200
    }
}

/// AVPlayerLayer, der den Bildschirm füllt (Aspect-Fill wie im Startbildschirm berechnet).
struct StartVideoFlaeche: UIViewRepresentable {
    let spieler: AVPlayer

    func makeUIView(context: Context) -> SpielerAnsicht {
        let ansicht = SpielerAnsicht()
        ansicht.spielerSchicht.player = spieler
        ansicht.spielerSchicht.videoGravity = .resizeAspectFill
        ansicht.backgroundColor = .clear
        return ansicht
    }

    func updateUIView(_ ansicht: SpielerAnsicht, context: Context) {}

    final class SpielerAnsicht: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var spielerSchicht: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
