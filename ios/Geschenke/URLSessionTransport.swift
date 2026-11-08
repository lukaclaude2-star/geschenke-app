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
        case .nichtErreichbar: return "Der Server ist gerade nicht erreichbar. Prüf dein Internet und versuch es nochmal."
        case .kiUeberlastet: return "Die KI ist gerade ausgelastet. Versuch es gleich nochmal."
        case .server(401): return "Die App kann sich gerade nicht beim Server anmelden. Lade die neueste Version aus dem App Store."
        case .server(429): return "Gerade kommen sehr viele Anfragen. Warte eine Minute und versuch es dann nochmal."
        case .server(let status): return "Beim Server ist etwas schiefgelaufen. Versuch es in einer Minute nochmal."
        case .unlesbar: return "Die Antwort kam nicht richtig an. Versuch es nochmal."
        }
    }
}

func fehlerText(_ fehler: Error) -> String {
    (fehler as? APIFehler)?.meldung ?? "Das hat nicht geklappt. Versuch es nochmal."
}

/// Render Free schläft nach 15 Minuten und braucht bis zu einer Minute zum Aufwachen.
let wachtAufText = "Einen Moment, ich bin gleich bei dir. Beim ersten Mal kann das bis zu einer Minute dauern."
