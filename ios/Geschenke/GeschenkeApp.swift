import GeschenkeCore
import SwiftUI

@main
struct GeschenkeApp: App {
    @StateObject private var zustand = AppZustand()

    init() {
        Self.steuerelementeEinfaerben()
        // Titel oben in der Leiste in Fraunces und Palettenfarbe statt Systemschrift in Weiß/Schwarz
        guard let fraunces = UIFont(name: Font.titelSchrift, size: 17) else { return }
        let farbe = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0xF1 / 255, green: 0xE3 / 255, blue: 0xC6 / 255, alpha: 1)
            : UIColor(red: 0x23 / 255, green: 0x16 / 255, blue: 0x0C / 255, alpha: 1) }
        UINavigationBar.appearance().titleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: fraunces),
            .foregroundColor: farbe,
        ]
        if let gross = UIFont(name: Font.titelSchrift, size: 34) {
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: gross),
                .foregroundColor: farbe,
            ]
        }
    }

    /// System-Regler und -Umschalter kommen sonst in Reinweiß und Systemgrau (DESIGN.md 2):
    /// Regler-Knopf Creme mit braunem Ring, gewähltes Segment Palettenbraun mit Creme-Schrift.
    private static func steuerelementeEinfaerben() {
        func farbe(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        func jeNachModus(abend: UInt32, hell: UInt32) -> UIColor {
            UIColor { $0.userInterfaceStyle == .dark ? farbe(abend) : farbe(hell) }
        }
        let braun = farbe(0x7B5930)
        let creme = jeNachModus(abend: 0xEBD9B4, hell: 0xF6E7C8)

        // Ein festes Bild für beide Modi: Der braune Ring hebt den Knopf auch von der hellen Karte ab.
        let durchmesser: CGFloat = 26, rand: CGFloat = 3
        let groesse = CGSize(width: durchmesser + 2 * rand, height: durchmesser + 2 * rand)
        let knopf = UIGraphicsImageRenderer(size: groesse).image { kontext in
            let kreis = CGRect(x: rand, y: rand, width: durchmesser, height: durchmesser).insetBy(dx: 1, dy: 1)
            kontext.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2,
                                        color: UIColor.black.withAlphaComponent(0.3).cgColor)
            farbe(0xEBD9B4).setFill()
            UIBezierPath(ovalIn: kreis).fill()
            kontext.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            braun.setStroke()
            let ring = UIBezierPath(ovalIn: kreis)
            ring.lineWidth = 2
            ring.stroke()
        }
        UISlider.appearance().setThumbImage(knopf, for: .normal)
        UISlider.appearance().setThumbImage(knopf, for: .highlighted)

        let segment = UISegmentedControl.appearance()
        segment.selectedSegmentTintColor = braun
        segment.backgroundColor = jeNachModus(abend: 0x3A2516, hell: 0xE6D9C3)
        let normal = UIFont(name: ZuhauseGewicht.normal.rawValue, size: 13) ?? .systemFont(ofSize: 13)
        let halbfett = UIFont(name: ZuhauseGewicht.halbfett.rawValue, size: 13) ?? .systemFont(ofSize: 13)
        segment.setTitleTextAttributes([
            .font: UIFontMetrics(forTextStyle: .footnote).scaledFont(for: normal),
            .foregroundColor: jeNachModus(abend: 0xF1E3C6, hell: 0x23160C),
        ], for: .normal)
        segment.setTitleTextAttributes([
            .font: UIFontMetrics(forTextStyle: .footnote).scaledFont(for: halbfett),
            .foregroundColor: creme,
        ], for: .selected)
    }

    var body: some Scene {
        WindowGroup {
            // Palette, Erscheinung und Startbildschirm entscheidet die Wurzel.
            Wurzel().environmentObject(zustand)
        }
    }
}

extension Schriftstufe {
    /// Normal = iOS-Standard; die Stufen greifen, weil die App Textstile statt fester Größen nutzt.
    var groesse: DynamicTypeSize {
        switch self {
        case .klein: return .small
        case .normal: return .large
        case .gross: return .xLarge
        case .sehrGross: return .xxLarge
        }
    }
}
