import Foundation
import GeschenkeCore

/// Hält Profile, Merkliste und Design und speichert jede Änderung sofort – nur auf dem Handy.
@MainActor
final class AppZustand: ObservableObject {
    @Published private(set) var daten: AppDaten
    @Published var zeigeEinstellungen = false
    private let speicher: AppDatenSpeicher

    init() {
        let ordner = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        speicher = AppDatenSpeicher(datei: ordner.appendingPathComponent("appdaten.json"))
        daten = speicher.laden()
        Look.palette = Designs.palette(daten.design)
    }

    var api: GeschenkeAPI {
        GeschenkeAPI(basis: Konfiguration.serverURL, token: Konfiguration.token, transport: URLSessionTransport())
    }

    func setzeDesign(_ id: String) {
        Look.palette = Designs.palette(id)
        daten.design = Look.palette.id
        sichern()
    }

    func setzeSchrift(_ stufe: Schriftstufe) {
        daten.schriftgroesse = stufe.rawValue
        sichern()
    }

    func setzeGeburtstag(_ id: UUID, _ geburtstag: Geburtstag?) {
        guard let i = daten.profile.firstIndex(where: { $0.id == id }) else { return }
        daten.profile[i].geburtstag = geburtstag
        sichern()
    }

    func profil(_ id: UUID) -> GespeichertesProfil? {
        daten.profile.first { $0.id == id }
    }

    @discardableResult
    func speichereProfil(name: String, profil: Profil, gewichtung: Gewichtung) -> UUID {
        let eintrag = GespeichertesProfil(name: name, profil: profil, gewichtung: gewichtung)
        daten.profile.append(eintrag)
        sichern()
        return eintrag.id
    }

    func aktualisiere(_ id: UUID, profil: Profil? = nil, gewichtung: Gewichtung? = nil) {
        guard let i = daten.profile.firstIndex(where: { $0.id == id }) else { return }
        if let profil { daten.profile[i].profil = profil }
        if let gewichtung { daten.profile[i].gewichtung = gewichtung }
        sichern()
    }

    /// Vom Wischen: Gelerntes und Gesehenes sichern, ohne eine zwischendurch per Chat
    /// geänderte Profilfassung zu überschreiben (Wünsche/Ausschlüsse/Budget kommen aus dem Profil).
    func sichereGelerntes(_ id: UUID, gewichtung: Gewichtung, gesehen: [String]) {
        guard let i = daten.profile.firstIndex(where: { $0.id == id }) else { return }
        var zusammen = gewichtung
        zusammen.uebernimm(profil: daten.profile[i].profil)
        daten.profile[i].gewichtung = zusammen
        daten.profile[i].gesehen = gesehen
        sichern()
    }

    func loescheProfile(_ ids: [UUID]) {
        daten.profile.removeAll { ids.contains($0.id) }
        sichern()
    }

    /// Liefert die ID des neuen Eintrags (für „Rückgängig“), nil wenn schon gemerkt.
    @discardableResult
    func merke(_ karte: Karte, fuer: String) -> UUID? {
        guard !daten.merkliste.contains(where: { $0.karte.id == karte.id && $0.fuer == fuer }) else { return nil }
        let eintrag = MerkEintrag(karte: karte, fuer: fuer)
        daten.merkliste.insert(eintrag, at: 0)
        sichern()
        return eintrag.id
    }

    func entferneMerk(_ ids: [UUID]) {
        daten.merkliste.removeAll { ids.contains($0.id) }
        sichern()
    }

    private func sichern() {
        try? speicher.speichern(daten)
    }
}
