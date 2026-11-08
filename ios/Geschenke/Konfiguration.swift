import Foundation
import GeschenkeCore

enum Konfiguration {
    static let serverURL = URL(string: "https://geschenke.onrender.com")!
    static let tokenSchluessel = "token"

    /// Token aus dem Build (GitHub-Secret). Fehlt er, kann man ihn in den Einstellungen eintragen.
    /// Der Build-Token gewinnt, damit ein alter gespeicherter Token nach einem Update nicht weiterlebt.
    static var token: String {
        if !tokenImBuild.isEmpty { return tokenImBuild }
        return (UserDefaults.standard.string(forKey: tokenSchluessel) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Spiegel von `AppDaten.hatKiEinwilligung`, den `AppZustand` pflegt. Liegt in UserDefaults,
    /// damit `GeschenkeAPI` ihn von jedem Thread aus lesen kann.
    static let einwilligungSchluessel = "kiEinwilligungAktiv"

    static func api() -> GeschenkeAPI {
        GeschenkeAPI(basis: serverURL, token: token, transport: URLSessionTransport(),
                     darfSenden: { UserDefaults.standard.bool(forKey: einwilligungSchluessel) })
    }

    /// Leer nur bei Builds ohne GitHub-Secret; nur dann zeigen die Einstellungen das Token-Feld.
    static var tokenImBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppToken") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
