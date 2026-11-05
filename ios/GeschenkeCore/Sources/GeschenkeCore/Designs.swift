import Foundation

/// Farben des einzigen Designs „Zuhause“ in den Farbwelten Abendlicht und Hell
/// (docs/design/palette-zuhause.md). Sie liegen hier statt in der App, damit ein Test die
/// Lesbarkeit prüfen kann.
public struct Palette: Equatable {
    public let hell: Bool
    public let hintergrund: UInt32
    public let karte: UInt32
    public let rand: UInt32
    public let text: UInt32
    public let akzent: UInt32
    /// Textfarbe auf Akzentflächen (z. B. Knopf „merken“, Abzeichen „für Mama“).
    public let aufAkzent: UInt32
    public let preis: UInt32
}

public enum Designs {
    public static let zuhauseAbend = Palette(
        hell: false, hintergrund: 0x23160C, karte: 0x452C1B, rand: 0x5E3F27, text: 0xF1E3C6,
        akzent: 0xC2721E, aufAkzent: 0x23160C, preis: 0xEFB249)

    // aufAkzent dunkel: das helle #FFF6E6 aus dem Muster erreicht auf Kupfer nur ca. 3,4.
    public static let zuhauseHell = Palette(
        hell: true, hintergrund: 0xEFE6D6, karte: 0xF8F1E5, rand: 0xE0D0B5, text: 0x23160C,
        akzent: 0xC2721E, aufAkzent: 0x23160C, preis: 0x9A3A24)

    /// Farbwelt nach der Einstellung „Erscheinung“ und dem Dunkelmodus des iPhones.
    public static func palette(erscheinung: Erscheinung, systemDunkel: Bool) -> Palette {
        switch erscheinung {
        case .automatisch: return systemDunkel ? zuhauseAbend : zuhauseHell
        case .hell: return zuhauseHell
        case .abendlicht: return zuhauseAbend
        }
    }

    /// Ob die App hell (`true`) oder dunkel (`false`) erzwingen soll; `nil` heißt: dem
    /// Dunkelmodus des iPhones folgen.
    public static func erzwingtHell(_ erscheinung: Erscheinung) -> Bool? {
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
