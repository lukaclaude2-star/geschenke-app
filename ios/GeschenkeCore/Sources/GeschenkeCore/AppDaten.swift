import Foundation

/// Alles, was die App speichert – nur auf dem Handy, kein Konto (Grundbaustein 10).
public struct AppDaten: Codable, Equatable {
    public var profile: [GespeichertesProfil] = []
    public var merkliste: [MerkEintrag] = []
    public var design: String = "nachtblau"
    /// Rohwert einer `Schriftstufe` – als Text gespeichert, damit unbekannte Werte nichts kaputt machen.
    public var schriftgroesse: String = "normal"
    /// Rohwert einer `Erscheinung` (nur im Design „Zuhause“ wirksam).
    public var erscheinung: String = "automatisch"
    /// Startbildschirm: Geschenk erst nach Tippen öffnen (sonst von selbst, sobald der Server wach ist).
    public var startTippen: Bool = true
    /// Rohwert eines `AuspackTempo`.
    public var auspacken: String = "normal"

    public init() {}

    enum CodingKeys: String, CodingKey {
        case profile, merkliste, design, schriftgroesse, erscheinung, startTippen, auspacken
    }

    // Neue Felder immer optional lesen – sonst landen die Daten aus v1 in appdaten.kaputt-*.json.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decodeIfPresent([GespeichertesProfil].self, forKey: .profile) ?? []
        merkliste = try c.decodeIfPresent([MerkEintrag].self, forKey: .merkliste) ?? []
        design = try c.decodeIfPresent(String.self, forKey: .design) ?? "nachtblau"
        schriftgroesse = try c.decodeIfPresent(String.self, forKey: .schriftgroesse) ?? "normal"
        erscheinung = try c.decodeIfPresent(String.self, forKey: .erscheinung) ?? "automatisch"
        startTippen = try c.decodeIfPresent(Bool.self, forKey: .startTippen) ?? true
        auspacken = try c.decodeIfPresent(String.self, forKey: .auspacken) ?? "normal"
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

    public init(id: UUID = UUID(), karte: Karte, fuer: String, datum: Date = Date()) {
        self.id = id
        self.karte = karte
        self.fuer = fuer
        self.datum = datum
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
}
