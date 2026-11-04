import GeschenkeCore
import SwiftUI

/// Aussehen der App. Standard ist Stil C – Nachtblau mit Gold (Grundbaustein 12); weitere
/// Designs wählt man in den Einstellungen. Die Farben kommen aus `Designs` im Kern.
enum Look {
    /// Wird von `AppZustand` gesetzt; die Wurzel-View hängt an `.id(design)` und zeichnet neu.
    static var palette: Palette = Designs.palette(Designs.standard)

    static var hintergrund: Color { Color(hex: palette.hintergrund) }
    static var karte: Color { Color(hex: palette.karte) }
    static var rand: Color { Color(hex: palette.rand) }
    static var akzent: Color { Color(hex: palette.akzent) }
    static var aufAkzent: Color { Color(hex: palette.aufAkzent) }
    static var preis: Color { Color(hex: palette.preis) }
    static var text: Color { Color(hex: palette.text) }
    static var leise: Color {
        // Zuhause: feste Palettenfarbe statt Deckkraft (Kontrast geprüft in palette-zuhause.md)
        if palette.stil == .zuhause { return Color(hex: palette.hell ? 0x7B5930 : 0xC0AE88) }
        return Color(hex: palette.text).opacity(0.6)
    }
    static var stil: DesignStil { palette.stil }
    /// Feine Linie um Knöpfe und Chips im Zuhause-Stil
    static var zuhauseLinie: Color { palette.hell ? Color(hex: 0x23160C).opacity(0.25) : Color(hex: 0x7B5930) }

    /// Titel auf Karten: Pinnwand in Handschrift, sonst die normale Überschrift.
    static var titelSchrift: Font {
        stil == .pinnwand ? .custom("Noteworthy-Bold", size: 19, relativeTo: .headline) : .headline
    }

    /// Runde Knöpfe – im Art-déco-Design als Raute.
    static var knopfForm: AnyShape {
        stil == .deco ? AnyShape(Rectangle().rotation(.degrees(45)).scale(0.72)) : AnyShape(Circle())
    }
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
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if Look.stil == .zuhause {
            configuration.label
                .font(.zuhause(.headline, .fett))
                .foregroundStyle(Look.aufAkzent)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Look.akzent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        } else {
            klassisch(configuration)
        }
    }

    private func klassisch(_ configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Look.aufAkzent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Look.akzent.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Look.stil == .deco ? 2 : 14))
    }
}

struct RandKnopf: ButtonStyle {
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if Look.stil == .zuhause {
            configuration.label
                .font(.zuhause(.headline, .fett))
                .foregroundStyle(Look.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Look.karte.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
                .overlay(Capsule().stroke(Look.zuhauseLinie, lineWidth: 1))
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        } else {
            klassisch(configuration)
        }
    }

    private func klassisch(_ configuration: Configuration) -> some View {
        let ecken: CGFloat = Look.stil == .deco ? 2 : 14
        return configuration.label
            .font(.headline)
            .foregroundStyle(Look.akzent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Look.karte.opacity(configuration.isPressed ? 0.6 : 1))
            .overlay(RoundedRectangle(cornerRadius: ecken).stroke(Look.akzent, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: ecken))
    }
}

struct Abzeichen: View {
    let text: String
    var gefuellt = false

    var body: some View {
        if Look.stil == .zuhause {
            // wie der Grund-Chip auf der Wischkarte
            Text(text)
                .font(.zuhause(.caption, .halbfett))
                .foregroundStyle(gefuellt ? Look.aufAkzent : Look.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(gefuellt ? Look.akzent : Color(hex: Look.palette.hell ? 0xE6D9C3 : 0x3A2516), in: Capsule())
                .overlay(Capsule().stroke(gefuellt ? Color.clear : Look.zuhauseLinie, lineWidth: 1))
        } else {
            klassisch
        }
    }

    private var klassisch: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(gefuellt ? Look.aufAkzent : Look.akzent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(gefuellt ? Look.akzent : Look.akzent.opacity(0.12))
            .overlay(Capsule().stroke(Look.akzent.opacity(0.4), lineWidth: 1))
            .clipShape(Capsule())
    }
}

/// Hintergrund je Design: einfarbig, im Art déco mit feinem Rautenmuster, als Pinnwand mit Kork.
struct DesignHintergrund: View {
    var body: some View {
        ZStack {
            Look.hintergrund
            switch Look.stil {
            case .deco:
                Canvas { kontext, groesse in
                    var pfad = Path()
                    let abstand: CGFloat = 16
                    var x: CGFloat = -groesse.height
                    while x < groesse.width + groesse.height {
                        pfad.move(to: CGPoint(x: x, y: 0))
                        pfad.addLine(to: CGPoint(x: x + groesse.height, y: groesse.height))
                        pfad.move(to: CGPoint(x: x + groesse.height, y: 0))
                        pfad.addLine(to: CGPoint(x: x, y: groesse.height))
                        x += abstand
                    }
                    kontext.stroke(pfad, with: .color(Look.akzent.opacity(0.06)), lineWidth: 1)
                }
            case .pinnwand:
                Canvas { kontext, groesse in
                    // Festes Muster statt Zufall, damit der Kork beim Neuzeichnen nicht flackert.
                    for i in 0..<900 {
                        let x = CGFloat((i * 73) % 997) / 997 * groesse.width
                        let y = CGFloat((i * 151) % 991) / 991 * groesse.height
                        let hell = i % 3 == 0
                        let punkt = CGRect(x: x, y: y, width: 2, height: 2)
                        kontext.fill(Path(ellipseIn: punkt),
                                     with: .color(hell ? Color.white.opacity(0.18) : Color.brown.opacity(0.35)))
                    }
                }
            case .normal:
                EmptyView()
            case .zuhause:
                // Lichtinsel: das einzige Leuchten, steht für die Lampe im Raum (DESIGN.md 2)
                GeometryReader { _ in
                    RadialGradient(colors: [Color(hex: 0xEFB249).opacity(Look.palette.hell ? 0.30 : 0.22), .clear],
                                   center: .center, startRadius: 0, endRadius: 202)
                        .frame(width: 404, height: 404)
                        .position(x: 130, y: 100)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    /// Hintergrund und Textfarbe des gewählten Designs (Name aus v1 beibehalten).
    func nachtblau() -> some View {
        self.foregroundStyle(Look.text)
            .background(DesignHintergrund().ignoresSafeArea())
            .scrollContentBackground(.hidden)
    }
}
