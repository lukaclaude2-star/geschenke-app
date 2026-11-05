import SwiftUI

/// Schrift im Zuhause-Stil (DESIGN.md 3): Nunito Sans für Text, Knöpfe und Preise, Fraunces
/// (weiche Serife) für Überschriften. Beide OFL, feste Schnitte aus `ios/werkzeuge/schriften`.
/// Immer an einen Textstil gebunden, damit Dynamic Type und die Schriftstufen der App greifen.
enum ZuhauseGewicht: String {
    case normal = "NunitoSans-Regular"
    case halbfett = "NunitoSans-SemiBold"
    case fett = "NunitoSans-Bold"
    case extrafett = "NunitoSans-ExtraBold"

    var system: Font.Weight {
        switch self {
        case .normal: return .regular
        case .halbfett: return .semibold
        case .fett: return .bold
        case .extrafett: return .heavy
        }
    }
}

extension Font {
    /// Für Ansichten, die alle Designs teilen: im Zuhause-Stil Nunito Sans, sonst Systemschrift
    /// im selben Gewicht (die alten Designs sehen unverändert aus).
    static func app(_ stil: Font.TextStyle, _ gewicht: ZuhauseGewicht = .normal) -> Font {
        Look.stil == .zuhause ? .zuhause(stil, gewicht) : .system(stil, weight: gewicht.system)
    }

    static func zuhause(_ stil: Font.TextStyle, _ gewicht: ZuhauseGewicht = .normal) -> Font {
        .custom(gewicht.rawValue, size: grundgroesse(stil), relativeTo: stil)
    }

    /// Überschriften: Seitentitel, Abschnitte, Einführung.
    static func titel(_ stil: Font.TextStyle) -> Font {
        .custom(titelSchrift, size: grundgroesse(stil), relativeTo: stil)
    }

    static let titelSchrift = "FrauncesSoft-Bold"

    /// iOS-Standardgrößen bei Schriftstufe „Groß“ (Standard).
    static func grundgroesse(_ stil: Font.TextStyle) -> CGFloat {
        switch stil {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}

/// Segmentierte Auswahl, ab großer Schrift ein Menü: Segmente würden lange Wörter sonst
/// abschneiden („Abendlicht“, „sehr groß“), DESIGN.md 3.
struct AuswahlStil: ViewModifier {
    @Environment(\.dynamicTypeSize) private var groesse

    func body(content: Content) -> some View {
        if groesse >= .xxLarge {
            content.pickerStyle(.menu)
        } else {
            content.pickerStyle(.segmented)
        }
    }
}

extension View {
    func auswahlStil() -> some View { modifier(AuswahlStil()) }
}
