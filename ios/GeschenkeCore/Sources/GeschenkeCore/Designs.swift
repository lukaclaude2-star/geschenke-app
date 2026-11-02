import Foundation

/// Wählbare Designs (Grundbaustein 12: Standard Nachtblau & Gold, weitere in den Einstellungen).
/// Die Farben liegen hier statt in der App, damit ein Test die Lesbarkeit prüfen kann.
public enum DesignStil: Equatable {
    case normal, deco, pinnwand
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
    public static let standard = "nachtblau"

    public static let alle: [Palette] = [
        Palette(id: "nachtblau", name: "Nachtblau & Gold", hell: false, stil: .normal,
                hintergrund: 0x11131C, karte: 0x1C1F2B, rand: 0x2C3040, text: 0xEEEEEE,
                akzent: 0xE0B84C, aufAkzent: 0x11131C, preis: 0xE0B84C),
        Palette(id: "wald", name: "Waldgrün & Messing", hell: false, stil: .normal,
                hintergrund: 0x0F1A14, karte: 0x18281F, rand: 0x2C4335, text: 0xEEF3EA,
                akzent: 0xC9A45C, aufAkzent: 0x1A1408, preis: 0xD8B874),
        Palette(id: "bordeaux", name: "Bordeaux & Creme", hell: false, stil: .normal,
                hintergrund: 0x1C0D11, karte: 0x2B1419, rand: 0x4A2229, text: 0xF7ECE4,
                akzent: 0xEFE0C8, aufAkzent: 0x3A1018, preis: 0xEFD7B0),
        Palette(id: "polarlicht", name: "Polarlicht", hell: false, stil: .normal,
                hintergrund: 0x0A1220, karte: 0x121D30, rand: 0x24365A, text: 0xE8F1FF,
                akzent: 0x4FE0C0, aufAkzent: 0x04211B, preis: 0xA98BFF),
        Palette(id: "graphit", name: "Graphit & Lime", hell: false, stil: .normal,
                hintergrund: 0x0C0C0C, karte: 0x171717, rand: 0x2C2C2C, text: 0xF5F5F5,
                akzent: 0xC8F53C, aufAkzent: 0x121A00, preis: 0xC8F53C),
        Palette(id: "mint", name: "Mint & Marine", hell: true, stil: .normal,
                hintergrund: 0xEEF6F3, karte: 0xFFFFFF, rand: 0xCFE3DC, text: 0x12263A,
                akzent: 0x14375E, aufAkzent: 0xFFFFFF, preis: 0x17735D),
        Palette(id: "deco", name: "Art déco", hell: false, stil: .deco,
                hintergrund: 0x0E1A17, karte: 0x13241F, rand: 0xC9A45C, text: 0xE9DCB8,
                akzent: 0xC9A45C, aufAkzent: 0x0E1A17, preis: 0xC9A45C),
        Palette(id: "pinnwand", name: "Polaroid-Pinnwand", hell: true, stil: .pinnwand,
                hintergrund: 0xC89A64, karte: 0xFDFDF8, rand: 0xE2D6C0, text: 0x2B2118,
                akzent: 0xC0392B, aufAkzent: 0xFFFFFF, preis: 0xC0392B),
    ]

    public static func palette(_ id: String) -> Palette {
        alle.first { $0.id == id } ?? alle[0]
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
