import GeschenkeCore
import SwiftUI

@main
struct GeschenkeApp: App {
    @StateObject private var zustand = AppZustand()

    init() {
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
