import GeschenkeCore
import SwiftUI

/// Wohin es zum Wischen geht: eine Person (Einzelsuche) oder mehrere (Sammelsuche).
struct WischZiel: Hashable, Identifiable {
    let id = UUID()
    let personen: [WischPerson]

    static func == (a: WischZiel, b: WischZiel) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Besitzt das Stapel-Modell für Wischen aus einem Profil oder der Sammelsuche.
struct WischZielView: View {
    @StateObject private var modell: KartenStapelModell

    init(ziel: WischZiel) {
        _modell = StateObject(wrappedValue: KartenStapelModell(personen: ziel.personen,
                                                              api: AppZustand.apiOhneZustand()))
    }

    var body: some View {
        ZuhauseWischView(modell: modell)
    }
}
