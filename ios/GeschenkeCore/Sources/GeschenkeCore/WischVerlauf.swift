import Foundation

/// Ein Wischer, der sich rückgängig machen lässt: alles, was er verändert hat.
public struct WischSchritt: Equatable {
    public let karte: Karte
    /// Index der Person im Stapel (0 bei der Einzelsuche).
    public let person: Int
    public let ja: Bool
    public let gewichtungVorher: Gewichtung
    /// Merklisten-Eintrag, den das Ja angelegt hat – beim Zurücknehmen wieder entfernen.
    public let merkID: UUID?

    public init(karte: Karte, person: Int, ja: Bool, gewichtungVorher: Gewichtung, merkID: UUID?) {
        self.karte = karte
        self.person = person
        self.ja = ja
        self.gewichtungVorher = gewichtungVorher
        self.merkID = merkID
    }
}

/// Die letzten Wischer für den Zurück-Knopf (höchstens 10).
public struct WischVerlauf {
    public static let maximum = 10
    private var schritte: [WischSchritt] = []

    public init() {}

    public var kannZurueck: Bool { !schritte.isEmpty }

    public mutating func merke(_ schritt: WischSchritt) {
        schritte.append(schritt)
        if schritte.count > Self.maximum {
            schritte.removeFirst(schritte.count - Self.maximum)
        }
    }

    public mutating func zurueck() -> WischSchritt? {
        schritte.popLast()
    }

    /// Nach einer Handänderung der Gewichtung (Regler, Zurücksetzen): Zurücknehmen dürfte diese
    /// Änderung sonst stillschweigend überschreiben (Grundbaustein 6).
    public mutating func vergiss(person: Int) {
        schritte.removeAll { $0.person == person }
    }
}
