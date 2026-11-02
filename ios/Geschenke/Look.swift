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
    static var leise: Color { Color(hex: palette.text).opacity(0.6) }
    static var stil: DesignStil { palette.stil }

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
    func makeBody(configuration: Configuration) -> some View {
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
    func makeBody(configuration: Configuration) -> some View {
        let ecken: CGFloat = Look.stil == .deco ? 2 : 14
        configuration.label
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
