import SwiftUI

/// Schrift im Zuhause-Stil: Nunito (OFL, rund und weich, DESIGN.md 3). Immer an einen Textstil
/// gebunden, damit Dynamic Type und die Schriftstufen der App weiter greifen.
enum ZuhauseGewicht: String {
    case normal = "Nunito-Regular"
    case halbfett = "Nunito-SemiBold"
    case fett = "Nunito-Bold"
    case extrafett = "Nunito-ExtraBold"
}

extension Font {
    static func zuhause(_ stil: Font.TextStyle, _ gewicht: ZuhauseGewicht = .normal) -> Font {
        .custom(gewicht.rawValue, size: grundgroesse(stil), relativeTo: stil)
    }

    /// iOS-Standardgrößen bei Schriftstufe „Groß“ (Standard).
    private static func grundgroesse(_ stil: Font.TextStyle) -> CGFloat {
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
