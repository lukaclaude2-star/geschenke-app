import Foundation

/// Wonach die Merkliste gruppiert wird (Umschalter oben in der Merkliste, wird gespeichert).
public enum MerkOrdnung: String, CaseIterable, Identifiable {
    case person, kategorie

    public var id: String { rawValue }

    public var titel: String {
        switch self {
        case .person: return "Personen"
        case .kategorie: return "Kategorien"
        }
    }

    public static func aus(_ rohwert: String) -> MerkOrdnung {
        MerkOrdnung(rawValue: rohwert) ?? .person
    }
}

public let sonstigesKategorie = "Sonstiges"

/// Kategorie einer Karte: Oberbereich des ersten Stichworts, das einen hat (Lebenslagen wie
/// „umzug“ haben keinen). Die KI vergibt das passendste Stichwort zuerst.
public func kategorie(_ karte: Karte) -> String {
    for tag in karte.tags {
        if let bereich = themaBereich[tag], let name = bereichNamen[bereich] { return name }
    }
    return sonstigesKategorie
}

public struct MerkGruppe: Equatable, Identifiable {
    public let titel: String
    public let eintraege: [MerkEintrag]
    public var id: String { titel }
}

/// Gruppen für die Merkliste. Nach Person in der Reihenfolge des Auftauchens (neueste zuerst),
/// nach Kategorie die größte zuerst, bei Gleichstand wie im Vokabular, „Sonstiges“ immer am Ende.
/// Gekauftes rutscht innerhalb der Gruppe nach unten.
public func merkGruppen(_ liste: [MerkEintrag], ordnung: MerkOrdnung) -> [MerkGruppe] {
    var reihenfolge: [String] = []
    var nachTitel: [String: [MerkEintrag]] = [:]
    for eintrag in liste {
        let titel = ordnung == .person ? eintrag.fuer : kategorie(eintrag.karte)
        if nachTitel[titel] == nil { reihenfolge.append(titel) }
        nachTitel[titel, default: []].append(eintrag)
    }
    if ordnung == .kategorie {
        let platz = Dictionary(uniqueKeysWithValues: bereichReihenfolge.enumerated()
            .compactMap { i, schluessel in bereichNamen[schluessel].map { ($0, i) } })
        reihenfolge.sort { a, b in
            if (a == sonstigesKategorie) != (b == sonstigesKategorie) { return b == sonstigesKategorie }
            let anzahlA = nachTitel[a]!.count, anzahlB = nachTitel[b]!.count
            if anzahlA != anzahlB { return anzahlA > anzahlB }
            return (platz[a] ?? Int.max) < (platz[b] ?? Int.max)
        }
    }
    return reihenfolge.map { titel in
        let eintraege = nachTitel[titel]!
        return MerkGruppe(titel: titel, eintraege: eintraege.filter { !$0.gekauft } + eintraege.filter(\.gekauft))
    }
}

/// Text zum Teilen der Ideen für eine Person (z. B. mit der Familie). Schon Gekauftes fehlt.
public func teilText(fuer: String, eintraege: [MerkEintrag]) -> String {
    let ideen = eintraege.filter { !$0.gekauft }.map { eintrag in
        let karte = eintrag.karte
        let unterzeile = [karte.preisText, karte.shop].filter { !$0.isEmpty }.joined(separator: " · ")
        return [karte.titel, unterzeile, karte.link].filter { !$0.isEmpty }.joined(separator: "\n")
    }
    return (["Geschenkideen für \(fuer)"] + ideen).joined(separator: "\n\n")
}
