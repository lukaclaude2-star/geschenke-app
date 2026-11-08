import SwiftUI

/// Kurze Einführung beim ersten Start (nach dem Startbildschirm) und auf Wunsch aus den
/// Einstellungen. Drei Seiten, jederzeit überspringbar (Apple HIG: kurz, überspringbar, nicht
/// wiederholt zeigen). Geblättert wird per Knopf, damit die Übungskarte auf Seite 2 frei
/// zur Seite gezogen werden kann.
struct EinfuehrungView: View {
    let fertig: () -> Void
    @Environment(\.dynamicTypeSize) private var schriftgroesse
    @State private var seite = 0

    private struct Seite {
        let titel: String
        let text: String
    }

    private let seiten = [
        Seite(titel: "erzähl mir\nvon der person.",
              text: "Ein kurzes Gespräch über Hobbys, Wünsche und das, was gar nicht geht. Mehr brauche ich nicht."),
        Seite(titel: "wisch dich durch.",
              text: "Nach rechts merkst du dir ein Geschenk, nach links geht es weiter. Mit jedem Wisch lerne ich dazu. Probier es mit der Karte aus."),
        Seite(titel: "gespeichert wird nur bei dir.",
              text: "Deine Leute und deine Merkliste liegen nur auf diesem iPhone. Für Vorschläge geht nur raus, was du über die Person erzählst. Kein Konto, keine Gerätekennung."),
    ]

    private var istLetzte: Bool { seite == seiten.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !istLetzte {
                    Button("Überspringen", action: fertig)
                        .font(.zuhause(.body, .halbfett))
                        .foregroundStyle(Look.leise)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .frame(height: 44)

            // Passt alles, steht der Text unten; bei sehr großer Schrift lässt sich scrollen.
            GeometryReader { geo in
                ScrollView {
                    // ZStack: alte und neue Seite liegen beim Überblenden übereinander, nicht untereinander
                    ZStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer(minLength: 8)
                            // Bild direkt über dem Text, kein Loch dazwischen
                            bild
                                .frame(maxWidth: .infinity)
                                .frame(height: schriftgroesse.isAccessibilitySize ? 170 : 320)
                                .padding(.bottom, 24)
                            VStack(alignment: .leading, spacing: 10) {
                                Text(seiten[seite].titel).font(.titel(.title))
                                    .foregroundStyle(Look.text)
                                    .accessibilityAddTraits(.isHeader)
                                Text(seiten[seite].text).font(.zuhause(.body))
                                    .foregroundStyle(Look.leise)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: geo.size.height, alignment: .bottom)
                        .id(seite)
                        .transition(.opacity)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            punkte.padding(.vertical, 16)
            Button(istLetzte ? "Los geht’s" : "Weiter") { weiter() }
                .buttonStyle(GoldKnopf())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .zuhauseHintergrund()
    }

    @ViewBuilder private var bild: some View {
        switch seite {
        case 0:
            Image("coco-familie").resizable().scaledToFit().accessibilityHidden(true)
        case 1:
            UebungsKarte()
        default:
            // die schlafende Katze zu Hause: alles bleibt bei dir
            Image("coco-katze").resizable().scaledToFit().accessibilityHidden(true)
        }
    }

    private var punkte: some View {
        HStack(spacing: 8) {
            ForEach(seiten.indices, id: \.self) { i in
                Capsule().fill(i == seite ? Look.akzent : Look.leise)
                    .frame(width: i == seite ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seite \(seite + 1) von \(seiten.count)")
    }

    private func weiter() {
        if istLetzte {
            fertig()
        } else {
            // Nur Überblenden, keine Bewegung (DESIGN.md 6)
            withAnimation(.easeInOut(duration: 0.25)) { seite += 1 }
        }
    }
}

/// Übungskarte auf Seite 2: lässt sich ziehen und werfen wie beim echten Wischen. Sie bleibt
/// verpackt wie ein guter Treffer (DESIGN.md 6b) und zeigt so kein erfundenes Produkt
/// (Grundbaustein 1).
private struct UebungsKarte: View {
    @Environment(\.accessibilityReduceMotion) private var bewegungReduziert
    @State private var versatz: CGFloat = 0
    @State private var sichtbar = true
    @State private var ergebnis: String?
    @State private var wuerfe = 0
    private let schwelle: CGFloat = 110

    var body: some View {
        VStack(spacing: 14) {
            karte
            HStack(alignment: .firstTextBaseline) {
                Text("‹ weiter")
                Spacer(minLength: 8)
                Text(ergebnis ?? "zieh die Karte").multilineTextAlignment(.center)
                Spacer(minLength: 8)
                Text("merken ›")
            }
            .font(.zuhause(.footnote, .halbfett)).foregroundStyle(Look.leise)
            .frame(maxWidth: 300)
            .accessibilityHidden(true)
        }
    }

    private var karte: some View {
        Verpackung(offen: 0, auspacken: 0, name: "dich", ruhig: true)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .zuhauseKarte(ecken: 24)
            .frame(width: 200)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) { stempel }
            .offset(x: bewegungReduziert ? 0 : versatz)
            .rotationEffect(.degrees(bewegungReduziert ? 0 : Double(versatz / 18)))
            .opacity(sichtbar ? 1 : 0)
            .gesture(
                DragGesture()
                    .onChanged { versatz = $0.translation.width }
                    .onEnded { wert in
                        let schwung = wert.predictedEndTranslation.width
                        if wert.translation.width > schwelle || schwung > schwelle * 2.6 {
                            werfen(ja: true)
                        } else if wert.translation.width < -schwelle || schwung < -schwelle * 2.6 {
                            werfen(ja: false)
                        } else {
                            withAnimation(.easeOut(duration: 0.22)) { versatz = 0 }
                        }
                    }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: wuerfe)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Übungskarte")
            .accessibilityValue(ergebnis ?? "")
            .accessibilityHint("Nach rechts ziehen zum Merken, nach links für weiter.")
            .accessibilityAction(named: "Merken") { werfen(ja: true) }
            .accessibilityAction(named: "Weiter") { werfen(ja: false) }
    }

    @ViewBuilder private var stempel: some View {
        HStack {
            Text("merken").font(.zuhause(.subheadline, .extrafett)).foregroundStyle(Look.aufAkzent)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Look.akzent, in: Capsule())
                .opacity(Double(max(0, versatz / 90)))
            Spacer()
            Text("weiter").font(.zuhause(.subheadline, .extrafett)).foregroundStyle(Look.text)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Look.flaeche, in: Capsule())
                .opacity(Double(max(0, -versatz / 90)))
        }
        .padding(14)
        .allowsHitTesting(false)
    }

    /// Wegfliegen (höchstens 280 ms, DESIGN.md 6), dann kommt die Karte mit dem Ergebnis wieder.
    private func werfen(ja: Bool) {
        wuerfe += 1
        withAnimation(.easeOut(duration: 0.25)) {
            if bewegungReduziert { sichtbar = false } else { versatz = ja ? 420 : -420 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            var ohneAnimation = Transaction()
            ohneAnimation.disablesAnimations = true
            withTransaction(ohneAnimation) {
                versatz = 0
                sichtbar = false
                ergebnis = ja ? "gemerkt. So landet ein Geschenk in der Merkliste." : "weiter. Dann kommt die nächste Karte."
            }
            withAnimation(.easeOut(duration: 0.25)) { sichtbar = true }
        }
    }
}
