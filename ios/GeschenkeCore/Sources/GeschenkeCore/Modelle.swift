import Foundation

// Spiegel der Server-Modelle (app/modelle.py). JSON-Schlüssel in snake_case über explizite
// CodingKeys – keine keyDecodingStrategy (Lehre aus dem Wecker).

public struct Wunsch: Codable, Equatable, Hashable {
    public var tag: String
    public var label: String
    public var gewicht: Double

    public init(tag: String, label: String, gewicht: Double) {
        self.tag = tag
        self.label = label
        self.gewicht = gewicht
    }
}

public struct Ausschluss: Codable, Equatable, Hashable {
    public var schluessel: String
    public var label: String

    public init(schluessel: String, label: String) {
        self.schluessel = schluessel
        self.label = label
    }
}

public struct Profil: Codable, Equatable {
    public var zusammenfassung: String
    public var wuensche: [Wunsch]
    public var ausschluesse: [Ausschluss]
    public var budgetMax: Double?
    public var budgetMin: Double?

    public init(zusammenfassung: String, wuensche: [Wunsch], ausschluesse: [Ausschluss], budgetMax: Double?,
                budgetMin: Double? = nil) {
        self.zusammenfassung = zusammenfassung
        self.wuensche = wuensche
        self.ausschluesse = ausschluesse
        self.budgetMax = budgetMax
        self.budgetMin = budgetMin
    }

    enum CodingKeys: String, CodingKey {
        case zusammenfassung, wuensche, ausschluesse
        case budgetMax = "budget_max"
        case budgetMin = "budget_min"
    }

    // Profile aus v1 haben kein budget_min.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zusammenfassung = try c.decode(String.self, forKey: .zusammenfassung)
        wuensche = try c.decode([Wunsch].self, forKey: .wuensche)
        ausschluesse = try c.decode([Ausschluss].self, forKey: .ausschluesse)
        budgetMax = try c.decodeIfPresent(Double.self, forKey: .budgetMax)
        budgetMin = try c.decodeIfPresent(Double.self, forKey: .budgetMin)
    }

    // Budget immer mitschicken (auch als null), damit der Server es eindeutig sieht.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(budgetMin, forKey: .budgetMin)
        try c.encode(zusammenfassung, forKey: .zusammenfassung)
        try c.encode(wuensche, forKey: .wuensche)
        try c.encode(ausschluesse, forKey: .ausschluesse)
        try c.encode(budgetMax, forKey: .budgetMax)
    }
}

public struct Karte: Codable, Equatable, Identifiable {
    public let id: String
    public let art: String
    public let titel: String
    public let preis: Double?
    public let preisVon: Double?
    public let preisBis: Double?
    public let bildURL: String?
    public let emoji: String?
    public let shop: String
    public let link: String
    public let tags: [String]
    /// Ideenkarte mit festem Foto zum Stichwort, das nur ein Beispiel zeigt.
    public let beispielbild: Bool?
    /// Partnerlink mit Provision: zeigt „Anzeige“ (§ 5a Abs. 4 UWG). Fehlt bei alten Merkliste-Einträgen.
    public let anzeige: Bool?

    public init(id: String, art: String, titel: String, preis: Double?, preisVon: Double?, preisBis: Double?,
                bildURL: String?, emoji: String?, shop: String, link: String, tags: [String],
                beispielbild: Bool? = nil, anzeige: Bool? = nil) {
        self.id = id
        self.art = art
        self.titel = titel
        self.preis = preis
        self.preisVon = preisVon
        self.preisBis = preisBis
        self.bildURL = bildURL
        self.emoji = emoji
        self.shop = shop
        self.link = link
        self.tags = tags
        self.beispielbild = beispielbild
        self.anzeige = anzeige
    }

    enum CodingKeys: String, CodingKey {
        case id, art, titel, preis, emoji, shop, link, tags, beispielbild, anzeige
        case preisVon = "preis_von"
        case preisBis = "preis_bis"
        case bildURL = "bild_url"
    }

    public var istIdee: Bool { art == "idee" }
    public var istBeispielbild: Bool { beispielbild == true }
    public var istAnzeige: Bool { anzeige == true }

    /// Nur Web-Links öffnen: Der Katalog kommt aus fremden Shop-Seiten, ein `javascript:`- oder
    /// `tel:`-Link soll nie aus der App heraus ausgelöst werden.
    public var sichererLink: URL? {
        guard let url = URL(string: link), let schema = url.scheme?.lowercased(),
              schema == "https" || schema == "http", let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    public var preisText: String {
        if let preis {
            return Self.euro(preis)
        }
        if let von = preisVon, let bis = preisBis {
            if von == bis { return "ca. \(Self.zahl(von)) €" }
            return "ca. \(Self.zahl(von))–\(Self.zahl(bis)) €"
        }
        if let bis = preisBis {
            return "bis ca. \(Self.zahl(bis)) €"
        }
        return ""
    }

    /// Versandkosten gehören direkt an den Preis (BGH, Froogle II). Ideenkarten haben keinen festen Preis.
    public var versandHinweis: String {
        preis != nil && !istIdee ? "zzgl. Versand" : ""
    }

    static func euro(_ wert: Double) -> String {
        String(format: "%.2f", wert).replacingOccurrences(of: ".", with: ",") + " €"
    }

    static func zahl(_ wert: Double) -> String {
        wert == wert.rounded() ? String(Int(wert)) : String(format: "%.2f", wert).replacingOccurrences(of: ".", with: ",")
    }
}

public struct ChatNachricht: Codable, Equatable, Identifiable {
    public var id = UUID()
    public let rolle: String  // "app" oder "nutzer"
    public let text: String

    public init(rolle: String, text: String) {
        self.rolle = rolle
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case rolle, text
    }
}

public struct ChatAntwort: Codable, Equatable {
    public let fertig: Bool
    public let frage: String?
    public let platzhalter: String?

    public init(fertig: Bool, frage: String?, platzhalter: String?) {
        self.fertig = fertig
        self.frage = frage
        self.platzhalter = platzhalter
    }
}

public struct KartenAntwort: Codable, Equatable {
    public let karten: [Karte]
    public let wirdDuenn: Bool
    public let tagLabels: [String: String]

    enum CodingKeys: String, CodingKey {
        case karten
        case wirdDuenn = "wird_duenn"
        case tagLabels = "tag_labels"
    }
}

/// Eine Person in der Sammelsuche; `id` kommt in `SammelKarte.fuer` zurück.
public struct SammelPerson: Encodable, Equatable {
    public let id: String
    public let profil: Profil
    public let gesehen: [String]

    public init(id: String, profil: Profil, gesehen: [String]) {
        self.id = id
        self.profil = profil
        self.gesehen = gesehen
    }
}

public struct SammelKarte: Codable, Equatable {
    public let fuer: String
    public let karte: Karte
}

public struct KartenSammelAntwort: Codable, Equatable {
    public let karten: [SammelKarte]
    public let duennFuer: [String]
    public let tagLabels: [String: String]

    enum CodingKeys: String, CodingKey {
        case karten
        case duennFuer = "duenn_fuer"
        case tagLabels = "tag_labels"
    }
}

// Anfragen an den Server

struct KartenSammelAnfrage: Encodable {
    let personen: [SammelPerson]
    let anzahl: Int
}

struct ChatAnfrage: Encodable {
    let laenge: String
    let nachrichten: [ChatNachricht]
}

struct ProfilAusGespraechAnfrage: Encodable {
    let nachrichten: [ChatNachricht]
}

struct ProfilAendernAnfrage: Encodable {
    let profil: Profil
    let anweisung: String
}

struct KartenAnfrage: Encodable {
    let profil: Profil
    let gesehen: [String]
    let anzahl: Int
}
