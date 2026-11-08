import Foundation
import GeschenkeCore

struct URLSessionTransport: Transport {
    func senden(_ anfrage: URLRequest) async throws -> (Data, Int) {
        let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        return (daten, (antwort as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

extension APIFehler {
    var meldung: String {
        switch self {
        case .nichtErreichbar: return "Der Server ist gerade nicht erreichbar. Bist du online?"
        case .kiUeberlastet: return "Die KI ist gerade ausgelastet. Versuch es gleich nochmal."
        case .server(401): return "Der Server kennt diese App nicht (Token falsch)."
        case .server(429): return "Gerade kommen sehr viele Anfragen. Warte eine Minute und versuch es dann nochmal."
        case .server(let status): return "Der Server hat einen Fehler gemeldet (\(status))."
        case .unlesbar: return "Die Antwort des Servers war unverständlich."
        case .keineEinwilligung: return "Ohne deine Zustimmung zur KI kann die App nichts an den Server schicken."
        }
    }
}

func fehlerText(_ fehler: Error) -> String {
    (fehler as? APIFehler)?.meldung ?? "Etwas ist schiefgegangen."
}

/// Render Free schläft nach 15 Minuten und braucht bis zu einer Minute zum Aufwachen.
let wachtAufText = "Der Server schläft noch, ich wecke ihn. Das dauert beim ersten Mal bis zu einer Minute."
