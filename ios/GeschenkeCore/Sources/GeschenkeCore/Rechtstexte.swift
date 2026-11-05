import Foundation

/// Impressum, Datenschutz und Co. aus `rechtliches/rechtliches.json`. Dieselbe Datei zeigt der
/// Server als Webseiten; die App bündelt sie, damit das Impressum auch ohne wachen Server in zwei
/// Tippern erreichbar ist (§ 5 DDG).
public struct Rechtstexte: Decodable, Equatable {
    public let stand: String
    public let angaben: [String: String]
    public let dokumente: [Rechtsdokument]

    public static func laden(_ daten: Data) throws -> Rechtstexte {
        try JSONDecoder().decode(Rechtstexte.self, from: daten)
    }

    /// Das Dokument mit ersetzten Platzhaltern (`{{name}}`, `{{stand}}`); unbekannte bleiben stehen.
    public func dokument(_ id: String) -> Rechtsdokument? {
        guard let roh = dokumente.first(where: { $0.id == id }) else { return nil }
        return Rechtsdokument(
            id: roh.id,
            titel: ausgefuellt(roh.titel),
            abschnitte: roh.abschnitte.map {
                Rechtsabschnitt(ueberschrift: $0.ueberschrift.map(ausgefuellt), absaetze: $0.absaetze.map(ausgefuellt))
            }
        )
    }

    /// Angaben, die noch Platzhalter in eckigen Klammern sind, z. B. „[Vor- und Nachname]“.
    public var offeneAngaben: [String] {
        angaben.filter { $0.value.hasPrefix("[") && $0.value.hasSuffix("]") }.map(\.key).sorted()
    }

    private func ausgefuellt(_ text: String) -> String {
        var ergebnis = text
        for (schluessel, wert) in angaben.merging(["stand": stand], uniquingKeysWith: { _, neu in neu }) {
            ergebnis = ergebnis.replacingOccurrences(of: "{{\(schluessel)}}", with: wert)
        }
        return ergebnis
    }
}

public struct Rechtsdokument: Decodable, Equatable, Identifiable {
    public let id: String
    public let titel: String
    public let abschnitte: [Rechtsabschnitt]
}

public struct Rechtsabschnitt: Decodable, Equatable {
    public let ueberschrift: String?
    /// Ein Absatz mit „- “ am Anfang ist ein Listenpunkt. Inline gibt es `**fett**` und `[Text](URL)`.
    public let absaetze: [String]
}
