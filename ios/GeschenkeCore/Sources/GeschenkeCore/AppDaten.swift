import Foundation

/// Alles, was die App speichert – nur auf dem Handy, kein Konto (Grundbaustein 10).
public struct AppDaten: Codable, Equatable {
    public var profile: [GespeichertesProfil] = []
    public var merkliste: [MerkEintrag] = []

    public init() {}
}

public struct GespeichertesProfil: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var profil: Profil
    public var gewichtung: Gewichtung

    public init(id: UUID = UUID(), name: String, profil: Profil, gewichtung: Gewichtung) {
        self.id = id
        self.name = name
        self.profil = profil
        self.gewichtung = gewichtung
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
