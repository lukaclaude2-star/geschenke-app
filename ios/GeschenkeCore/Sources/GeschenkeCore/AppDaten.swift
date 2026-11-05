import Foundation

/// Alles, was die App speichert – nur auf dem Handy, kein Konto (Grundbaustein 10).
public struct AppDaten: Codable, Equatable {
    public var profile: [GespeichertesProfil] = []
    public var merkliste: [MerkEintrag] = []
    /// Rohwert einer `Schriftstufe` – als Text gespeichert, damit unbekannte Werte nichts kaputt machen.
    public var schriftgroesse: String = "normal"
    /// Rohwert einer `Erscheinung` (Hell, Abendlicht oder dem iPhone folgen).
    public var erscheinung: String = "automatisch"
    /// Startbildschirm: Geschenk erst nach Tippen öffnen (sonst von selbst, sobald der Server wach ist).
    public var startTippen: Bool = true
    /// Rohwert eines `AuspackTempo`.
    public var auspacken: String = "normal"
    /// Rohwert einer `MerkOrdnung` (Merkliste nach Personen oder Kategorien).
    public var merkOrdnung: String = "person"
    /// Die Einführung beim ersten Start wurde gezeigt (oder übersprungen).
    public var einfuehrungGesehen: Bool = false
    /// Version des Zustimmungstexts, dem zugestimmt wurde (0 = keine Zustimmung). Apple 5.1.2(i):
    /// Vor der ersten Übertragung an die KI muss die Person ausdrücklich zustimmen.
    public var kiEinwilligung: Int = 0

    /// Ändert sich, was an wen geht, steigt die Version und die App fragt erneut.
    public static let kiEinwilligungVersion = 1

    public var hatKiEinwilligung: Bool { kiEinwilligung == Self.kiEinwilligungVersion }

    public init() {}

    enum CodingKeys: String, CodingKey {
        case profile, merkliste, schriftgroesse, erscheinung, startTippen, auspacken
        case merkOrdnung, einfuehrungGesehen, kiEinwilligung
    }

    // Neue Felder immer optional lesen – sonst landen die Daten aus v1 in appdaten.kaputt-*.json.
    // Der Schlüssel „design“ aus der Zeit mit mehreren Designs wird einfach übergangen.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decodeIfPresent([GespeichertesProfil].self, forKey: .profile) ?? []
        merkliste = try c.decodeIfPresent([MerkEintrag].self, forKey: .merkliste) ?? []
        schriftgroesse = try c.decodeIfPresent(String.self, forKey: .schriftgroesse) ?? "normal"
        erscheinung = try c.decodeIfPresent(String.self, forKey: .erscheinung) ?? "automatisch"
        startTippen = try c.decodeIfPresent(Bool.self, forKey: .startTippen) ?? true
        auspacken = try c.decodeIfPresent(String.self, forKey: .auspacken) ?? "normal"
        merkOrdnung = try c.decodeIfPresent(String.self, forKey: .merkOrdnung) ?? "person"
        einfuehrungGesehen = try c.decodeIfPresent(Bool.self, forKey: .einfuehrungGesehen) ?? false
        kiEinwilligung = try c.decodeIfPresent(Int.self, forKey: .kiEinwilligung) ?? 0
    }
}

public struct GespeichertesProfil: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var profil: Profil
    public var gewichtung: Gewichtung
    /// Gewischte Karten – kommen bei diesem Profil nicht wieder (bis „Gesehene wieder zeigen“).
    public var gesehen: [String]
    /// Freiwillig – für den Countdown auf der Startseite.
    public var geburtstag: Geburtstag?

    public init(id: UUID = UUID(), name: String, profil: Profil, gewichtung: Gewichtung, gesehen: [String] = []) {
        self.id = id
        self.name = name
        self.profil = profil
        self.gewichtung = gewichtung
        self.gesehen = gesehen
    }

    enum CodingKeys: String, CodingKey {
        case id, name, profil, gewichtung, gesehen, geburtstag
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        profil = try c.decode(Profil.self, forKey: .profil)
        gewichtung = try c.decode(Gewichtung.self, forKey: .gewichtung)
        gesehen = try c.decodeIfPresent([String].self, forKey: .gesehen) ?? []
        geburtstag = try c.decodeIfPresent(Geburtstag.self, forKey: .geburtstag)
    }
}

public struct MerkEintrag: Codable, Equatable, Identifiable {
    public let id: UUID
    public let karte: Karte
    public let fuer: String
    public let datum: Date
    /// In der Merkliste abgehakt: schon gekauft.
    public var gekauft: Bool

    public init(id: UUID = UUID(), karte: Karte, fuer: String, datum: Date = Date(), gekauft: Bool = false) {
        self.id = id
        self.karte = karte
        self.fuer = fuer
        self.datum = datum
        self.gekauft = gekauft
    }

    enum CodingKeys: String, CodingKey {
        case id, karte, fuer, datum, gekauft
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        karte = try c.decode(Karte.self, forKey: .karte)
        fuer = try c.decode(String.self, forKey: .fuer)
        datum = try c.decode(Date.self, forKey: .datum)
        gekauft = try c.decodeIfPresent(Bool.self, forKey: .gekauft) ?? false
    }
}

public final class AppDatenSpeicher {
    private let datei: URL
    private var unlesbar = false

    public init(datei: URL) {
        self.datei = datei
    }

    /// Fehlende oder kaputte Datei → leere Daten, die App startet trotzdem.
    public func laden() -> AppDaten {
        guard let daten = try? Data(contentsOf: datei) else { return AppDaten() }
        guard let geladen = try? JSONDecoder().decode(AppDaten.self, from: daten) else {
            unlesbar = true
            return AppDaten()
        }
        return geladen
    }

    public func speichern(_ daten: AppDaten) throws {
        if unlesbar {
            // Unlesbare Daten (z. B. nach einem App-Update) nicht überschreiben, sondern beiseitelegen –
            // so sind Profile und Merkliste nicht endgültig weg.
            let stempel = Int(Date().timeIntervalSince1970)
            let sicherung = datei.deletingLastPathComponent()
                .appendingPathComponent("appdaten.kaputt-\(stempel).json")
            try? FileManager.default.moveItem(at: datei, to: sicherung)
            unlesbar = false
        }
        let kodiert = try JSONEncoder().encode(daten)
        try kodiert.write(to: datei, options: .atomic)
    }

    /// „Alle Daten löschen“: die Datei und alle beiseitegelegten unlesbaren Fassungen, denn auch
    /// die enthalten Profile und Merkliste.
    public func loescheAlles() throws {
        let ordner = datei.deletingLastPathComponent()
        let dateien = (try? FileManager.default.contentsOfDirectory(atPath: ordner.path)) ?? []
        for name in dateien where name == datei.lastPathComponent || name.hasPrefix("appdaten.kaputt-") {
            try FileManager.default.removeItem(at: ordner.appendingPathComponent(name))
        }
        unlesbar = false
    }
}
