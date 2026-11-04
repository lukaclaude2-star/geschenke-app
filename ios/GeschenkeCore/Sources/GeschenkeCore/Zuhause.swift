import Foundation

/// Farbwelt im Design „Zuhause“ (DESIGN.md 2): dem Dunkelmodus des iPhones folgen oder fest wählen.
public enum Erscheinung: String, CaseIterable, Identifiable {
    case automatisch, hell, abendlicht

    public var id: String { rawValue }

    public var titel: String {
        switch self {
        case .automatisch: return "Automatisch"
        case .hell: return "Hell"
        case .abendlicht: return "Abendlicht"
        }
    }

    public static func aus(_ rohwert: String) -> Erscheinung {
        Erscheinung(rawValue: rohwert) ?? .automatisch
    }
}

/// Kleingeschriebene Begrüßung auf der Startseite (DESIGN.md 3).
public func begruessung(stunde: Int) -> String {
    switch stunde {
    case 5...10: return "guten morgen."
    case 11...17: return "guten tag."
    default: return "guten abend."
    }
}

/// Wie schnell sich richtig gute Treffer auf der Wischkarte auspacken (DESIGN.md 6b, Einstellungen).
public enum AuspackTempo: String, CaseIterable, Identifiable {
    case langsam, normal, schnell, aus

    public var id: String { rawValue }

    /// Sekunden fürs Auspacken; 0 heißt: Die Verpackung verschwindet nur mit dem Wischen.
    public var dauer: Double {
        switch self {
        case .langsam: return 1.3
        case .normal: return 0.8
        case .schnell: return 0.45
        case .aus: return 0
        }
    }

    public var titel: String {
        switch self {
        case .langsam: return "langsam"
        case .normal: return "normal"
        case .schnell: return "schnell"
        case .aus: return "aus"
        }
    }

    public static func aus(_ rohwert: String) -> AuspackTempo {
        AuspackTempo(rawValue: rohwert) ?? .normal
    }
}

/// Wie gut eine Karte laut Stichwörtern zur Person passt: Summe der Gewichte ihrer Tags.
/// Die Provision kommt hier bewusst nicht vor (Grundbaustein 4).
func punktzahl(_ karte: Karte, gewichtung: Gewichtung) -> Double {
    Set(karte.tags).reduce(0.0) { $0 + (gewichtung.gewichte[$1] ?? 0) }
}

/// IDs der Karten, die sich im Design „Zuhause“ richtig auspacken (DESIGN.md 6b): die besten
/// `anteil` nach Punktzahl, ab 5 Karten mindestens eine. Unter 5 Karten wäre „richtig gut“
/// beliebig, deshalb gibt es dann keinen Treffer. Karten ohne positive Punktzahl zählen nie.
/// Bei Gleichstand gewinnt die Karte, die weiter vorn liegt.
public func richtigGuteTreffer(_ karten: [Karte], gewichtung: Gewichtung, anteil: Double = 0.1) -> Set<String> {
    var anzahl = Int((Double(karten.count) * anteil).rounded())
    if karten.count >= 5 {
        anzahl = max(anzahl, 1)
    }
    guard anzahl > 0 else { return [] }
    let punkte: [Double] = karten.map { punktzahl($0, gewichtung: gewichtung) }
    let positiv: [Int] = karten.indices.filter { punkte[$0] > 0 }
    let reihenfolge: [Int] = positiv.sorted { (a: Int, b: Int) -> Bool in
        if punkte[a] != punkte[b] {
            return punkte[a] > punkte[b]
        }
        return a < b
    }
    let ids: [String] = reihenfolge.prefix(anzahl).map { karten[$0].id }
    return Set(ids)
}

/// Grund-Chip auf der Wischkarte: Label des passenden Tags mit dem höchsten Gewicht.
/// `nil`, wenn kein Tag der Karte ein positives Gewicht hat.
public func passtWeil(_ karte: Karte, gewichtung: Gewichtung) -> String? {
    var bester: String?
    var besteGewicht = 0.0
    // Sortiert durchgehen, damit bei gleichem Gewicht nicht zufällig ein anderer Chip erscheint.
    for tag in Set(karte.tags).sorted() {
        let gewicht = gewichtung.gewichte[tag] ?? 0
        if gewicht > besteGewicht {
            bester = tag
            besteGewicht = gewicht
        }
    }
    guard let tag = bester else { return nil }
    return gewichtung.labels[tag] ?? tag
}
