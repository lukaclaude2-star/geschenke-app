import GeschenkeCore
import SwiftUI

@main
struct GeschenkeApp: App {
    @StateObject private var zustand = AppZustand()

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
