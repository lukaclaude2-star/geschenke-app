import Foundation

/// Das Design der App: nur noch „Zuhause“ mit Abendlicht und Hell (Luka, 05.11.2026).
/// Die übrigen Designs sind entfernt; ihre Stile bleiben im Enum, bis die Views aufgeräumt sind.
/// Die Farben liegen hier statt in der App, damit ein Test die Lesbarkeit prüfen kann.
public enum DesignStil: Equatable {
    case normal, deco, pinnwand, zuhause
}

public struct Palette: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let hell: Bool
    public let stil: DesignStil
    public let hintergrund: UInt32
    public let karte: UInt32
    public let rand: UInt32
    public let text: UInt32
    public let akzent: UInt32
    /// Textfarbe auf Akzentflächen (z. B. Herz-Knopf, Abzeichen „für Mama“).
    public let aufAkzent: UInt32
    public let preis: UInt32
}

public enum Designs {
    public static let standard = zuhauseID

    public static let alle: [Palette] = [
        zuhauseAbend,
    ]

    /// „Zuhause“ hat zwei Farbwelten (docs/design/palette-zuhause.md). In `alle` steht nur das
    /// Abendlicht; welche Farbwelt gilt, entscheidet `palette(_:erscheinung:systemDunkel:)`.
    public static let zuhauseID = "zuhause"

    public static let zuhauseAbend = Palette(
        id: zuhauseID, name: "Zuhause", hell: false, stil: .zuhause,
        hintergrund: 0x23160C, karte: 0x452C1B, rand: 0x5E3F27, text: 0xF1E3C6,
        akzent: 0xC2721E, aufAkzent: 0x23160C, preis: 0xEFB249)

    // aufAkzent dunkel: das helle #FFF6E6 aus dem Muster erreicht auf Kupfer nur ca. 3,4.
    public static let zuhauseHell = Palette(
        id: zuhauseID, name: "Zuhause", hell: true, stil: .zuhause,
        hintergrund: 0xEFE6D6, karte: 0xF8F1E5, rand: 0xE0D0B5, text: 0x23160C,
        akzent: 0xC2721E, aufAkzent: 0x23160C, preis: 0x9A3A24)

    public static func palette(_ id: String) -> Palette {
        alle.first { $0.id == id } ?? alle[0]
    }

    /// Palette mit Blick auf die Erscheinung. Alte, gespeicherte Design-IDs landen ebenfalls bei
    /// „Zuhause“, deshalb spielt die ID keine Rolle mehr.
    public static func palette(_ id: String, erscheinung: Erscheinung, systemDunkel: Bool) -> Palette {
        switch erscheinung {
        case .automatisch: return systemDunkel ? zuhauseAbend : zuhauseHell
        case .hell: return zuhauseHell
        case .abendlicht: return zuhauseAbend
        }
    }

    /// Ob die App hell (`true`) oder dunkel (`false`) erzwingen soll; `nil` heißt: dem
    /// Dunkelmodus des iPhones folgen.
    public static func erzwingtHell(_ id: String, erscheinung: Erscheinung) -> Bool? {
        switch erscheinung {
        case .automatisch: return nil
        case .hell: return true
        case .abendlicht: return false
        }
    }
}

/// WCAG-Kontrastverhältnis zweier Farben (1 bis 21; ab 4,5 gut lesbar).
public func kontrast(_ a: UInt32, _ b: UInt32) -> Double {
    let la = leuchtdichte(a), lb = leuchtdichte(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

private func leuchtdichte(_ farbe: UInt32) -> Double {
    func kanal(_ wert: UInt32) -> Double {
        let c = Double(wert & 0xFF) / 255
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * kanal(farbe >> 16) + 0.7152 * kanal(farbe >> 8) + 0.0722 * kanal(farbe)
}
