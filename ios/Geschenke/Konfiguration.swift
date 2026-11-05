import Foundation

enum Konfiguration {
    static let serverURL = URL(string: "https://geschenke.onrender.com")!
    static let tokenSchluessel = "token"

    /// Token aus dem Build (GitHub-Secret). Fehlt er, kann man ihn in den Einstellungen eintragen.
    static var token: String {
        let gespeichert = (UserDefaults.standard.string(forKey: tokenSchluessel) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !gespeichert.isEmpty { return gespeichert }
        return tokenImBuild
    }

    /// Leer nur bei Builds ohne GitHub-Secret; nur dann zeigen die Einstellungen das Token-Feld.
    static var tokenImBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppToken") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
