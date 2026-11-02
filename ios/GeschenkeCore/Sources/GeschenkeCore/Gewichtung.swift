import Foundation

/// Was die App beim Wischen über die Person lernt (Grundbaustein 6: sichtbar, änderbar, zurücksetzbar).
///
/// Ein Ja hebt die Schlagwörter der Karte stärker, als ein Nein sie senkt. Wird sehr einseitig
/// Nein gesagt, zählen die wenigen Ja deutlich mehr (bis zum Dreifachen).
public struct Gewichtung: Codable, Equatable {
    public static let jaSchritt = 0.15
    public static let neinSchritt = 0.05
    public static let neuStart = 0.3
    public static let minimum = 0.0
    public static let maximum = 2.0
    static let fenster = 20
    static let mindestEntscheidungen = 5

    public private(set) var gewichte: [String: Double]
    public private(set) var start: [String: Double]
    public private(set) var verlauf: [Bool]
    public private(set) var labels: [String: String]

    public init(profil: Profil) {
        var gewichte: [String: Double] = [:]
        var labels: [String: String] = [:]
        for w in profil.wuensche {
            gewichte[w.tag] = Self.geklemmt(w.gewicht)
            labels[w.tag] = w.label
        }
        self.gewichte = gewichte
        self.start = gewichte
        self.verlauf = []
        self.labels = labels
    }

    private var neinAnteil: Double {
        guard verlauf.count >= Self.mindestEntscheidungen else { return 0 }
        let letzte = verlauf.suffix(Self.fenster)
        return Double(letzte.filter { !$0 }.count) / Double(letzte.count)
    }

    public mutating func ja(tags: [String]) {
        let schritt = Self.jaSchritt * (1 + 2 * neinAnteil)
        for tag in Set(tags) {
            if let alt = gewichte[tag] {
                gewichte[tag] = Self.geklemmt(alt + schritt)
            } else {
                gewichte[tag] = Self.neuStart
            }
        }
        verlauf.append(true)
    }

    public mutating func nein(tags: [String]) {
        for tag in Set(tags) {
            if let alt = gewichte[tag] {
                gewichte[tag] = Self.geklemmt(alt - Self.neinSchritt)
            }
        }
        verlauf.append(false)
    }

    public mutating func setze(_ tag: String, auf wert: Double) {
        gewichte[tag] = Self.geklemmt(wert)
    }

    public mutating func zuruecksetzen() {
        gewichte = start
        verlauf = []
    }

    public mutating func merkeLabels(_ neue: [String: String]) {
        labels.merge(neue) { alt, _ in alt }
    }

    /// Nach „Profil per Chat ändern“: neue Wünsche kommen mit ihrem Gewicht dazu, entfernte
    /// Wünsche fallen weg, gelernte Werte bestehender Wünsche bleiben – außer die Änderung hat
    /// ihr Gewicht ausdrücklich neu gesetzt („Garten ist ihr jetzt nicht mehr so wichtig“).
    public mutating func uebernimm(profil: Profil) {
        let neu = Dictionary(profil.wuensche.map { ($0.tag, Self.geklemmt($0.gewicht)) }) { a, _ in a }
        for tag in start.keys where neu[tag] == nil {
            gewichte[tag] = nil
        }
        for (tag, wert) in neu where start[tag] != wert {
            gewichte[tag] = wert
        }
        start = neu
        for w in profil.wuensche {
            labels[w.tag] = w.label
        }
    }

    /// Profil mit den gelernten Gewichten – so geht es an den Server.
    public func angewendet(auf profil: Profil) -> Profil {
        var ergebnis = profil
        var wuensche: [Wunsch] = []
        for w in profil.wuensche {
            wuensche.append(Wunsch(tag: w.tag, label: w.label, gewicht: gewichte[w.tag] ?? w.gewicht))
        }
        let bekannt = Set(profil.wuensche.map(\.tag))
        for tag in gewichte.keys.sorted() where !bekannt.contains(tag) {
            wuensche.append(Wunsch(tag: tag, label: labels[tag] ?? tag, gewicht: gewichte[tag]!))
        }
        ergebnis.wuensche = wuensche
        return ergebnis
    }

    /// Für die Schieberegler, sortiert nach Gewicht.
    public var eintraege: [GewichtEintrag] {
        gewichte.map { GewichtEintrag(tag: $0.key, label: labels[$0.key] ?? $0.key, gewicht: $0.value) }
            .sorted { $0.gewicht == $1.gewicht ? $0.tag < $1.tag : $0.gewicht > $1.gewicht }
    }

    public static func stufe(_ gewicht: Double) -> String {
        if gewicht < 0.7 { return "schwach" }
        if gewicht > 1.3 { return "stark" }
        return "normal"
    }

    static func geklemmt(_ wert: Double) -> Double {
        min(maximum, max(minimum, wert))
    }
}

public struct GewichtEintrag: Identifiable, Equatable {
    public let tag: String
    public let label: String
    public let gewicht: Double
    public var id: String { tag }
}
