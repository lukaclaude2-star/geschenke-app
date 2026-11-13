import GeschenkeCore
import SwiftUI

/// Farben der App im Design „Zuhause“ (DESIGN.md 2). Die Werte kommen aus `Designs` im Kern.
enum Look {
    /// Wird von der Wurzel gesetzt; die Wurzel hängt an `.id(...)` und zeichnet beim Wechsel neu.
    static var palette: Palette = Designs.zuhauseAbend

    static var hintergrund: Color { Color(hex: palette.hintergrund) }
    static var karte: Color { Color(hex: palette.karte) }
    static var rand: Color { Color(hex: palette.rand) }
    static var akzent: Color { Color(hex: palette.akzent) }
    /// Akzent als Schrift oder Symbol auf dem Grund: Kupfer erreicht in Hell nur 2,97, dort
    /// deshalb Rotdunkel (5,64). Als Fläche bleibt überall `akzent`.
    static var akzentText: Color { palette.hell ? Color(hex: palette.preis) : akzent }
    static var aufAkzent: Color { Color(hex: palette.aufAkzent) }
    static var preis: Color { Color(hex: palette.preis) }
    static var text: Color { Color(hex: palette.text) }
    /// Zweitrangiger Text: feste Palettenfarbe statt Deckkraft (Kontrast geprüft in palette-zuhause.md)
    static var leise: Color { Color(hex: palette.hell ? 0x7B5930 : 0xC0AE88) }
    /// Feine Linie um Knöpfe und Chips
    static var linie: Color { palette.hell ? Color(hex: 0x23160C).opacity(0.25) : Color(hex: 0x7B5930) }
    /// Fläche für Chips und den Umschalter
    static var flaeche: Color { Color(hex: palette.hell ? 0xE6D9C3 : 0x3A2516) }
    /// Trennlinie zwischen Zeilen
    static var trenner: some View { flaeche.frame(height: 1) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct GoldKnopf: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.zuhause(.headline, .fett))
            .foregroundStyle(Look.aufAkzent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Look.akzent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RandKnopf: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.zuhause(.headline, .fett))
            .foregroundStyle(Look.text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Look.karte.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
            .overlay(Capsule().stroke(Look.linie, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Chip für Stichwörter, „Idee“ und „für Mama“.
struct Abzeichen: View {
    let text: String
    var gefuellt = false

    var body: some View {
        Text(text)
            .font(.zuhause(.caption, .halbfett))
            .foregroundStyle(gefuellt ? Look.aufAkzent : Look.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(gefuellt ? Look.akzent : Look.flaeche, in: Capsule())
            .overlay(Capsule().stroke(gefuellt ? Color.clear : Look.linie, lineWidth: 1))
    }
}

/// Hintergrund mit Lichtinsel: das einzige Leuchten, steht für die Lampe im Raum (DESIGN.md 2).
struct ZuhauseHintergrund: View {
    var body: some View {
        ZStack {
            Look.hintergrund
            GeometryReader { _ in
                RadialGradient(colors: [Color(hex: 0xEFB249).opacity(Look.palette.hell ? 0.30 : 0.22), .clear],
                               center: .center, startRadius: 0, endRadius: 202)
                    .frame(width: 404, height: 404)
                    // Fest bei 130/100: dorthin zieht sich auch das Licht des Startbildschirms zusammen
                    .position(x: 130, y: 100)
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Hintergrund und Textfarbe der App.
    func zuhauseHintergrund() -> some View {
        self.foregroundStyle(Look.text)
            .background(ZuhauseHintergrund().ignoresSafeArea())
            .scrollContentBackground(.hidden)
    }

    /// Tastatur immer schließbar: Knopf über der Tastatur und Wegziehen beim Scrollen.
    /// Mehrzeilige Felder haben keine Fertig-Taste – Return macht dort nur eine neue Zeile.
    func tastaturSchliessbar() -> some View {
        self.scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("Tastatur schließen")
                }
            }
    }

    /// Listen und Formulare ohne Kachelflächen: Zeilen direkt auf dem Hintergrund, feine Linien
    /// dazwischen (Luka, 05.11.2026: „die Kacheln weglassen“).
    func offeneZeilen() -> some View {
        self.listRowBackground(Color.clear)
            .listRowSeparatorTint(Look.flaeche)
    }
}

/// Überschrift eines Abschnitts (Fraunces), z. B. „Deine Leute“ auf der Startseite.
struct Abschnittstitel: View {
    let text: String

    var body: some View {
        Text(text).font(.titel(.title3)).foregroundStyle(Look.text)
            .accessibilityAddTraits(.isHeader)
    }
}
