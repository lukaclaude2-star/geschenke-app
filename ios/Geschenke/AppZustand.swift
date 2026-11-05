import Foundation
import GeschenkeCore

/// Hält Profile, Merkliste und Einstellungen und speichert jede Änderung sofort – nur auf dem Handy.
@MainActor
final class AppZustand: ObservableObject {
    @Published private(set) var daten: AppDaten
    private let speicher: AppDatenSpeicher

    init() {
        let ordner = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        speicher = AppDatenSpeicher(datei: ordner.appendingPathComponent("appdaten.json"))
        daten = speicher.laden()
    }

    var api: GeschenkeAPI {
        GeschenkeAPI(basis: Konfiguration.serverURL, token: Konfiguration.token, transport: URLSessionTransport())
    }

    func setzeSchrift(_ stufe: Schriftstufe) {
        daten.schriftgroesse = stufe.rawValue
        sichern()
    }

    func setzeErscheinung(_ erscheinung: Erscheinung) {
        daten.erscheinung = erscheinung.rawValue
        sichern()
    }

    func setzeStartTippen(_ an: Bool) {
        daten.startTippen = an
        sichern()
    }

    func setzeAuspacken(_ tempo: AuspackTempo) {
        daten.auspacken = tempo.rawValue
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

    /// „Alles löschen“ in der Merkliste (nur nach Bestätigung aufrufen).
    func leereMerkliste() {
        daten.merkliste = []
        sichern()
    }

    func setzeGekauft(_ id: UUID, _ gekauft: Bool) {
        guard let i = daten.merkliste.firstIndex(where: { $0.id == id }) else { return }
        daten.merkliste[i].gekauft = gekauft
        sichern()
    }

    func setzeMerkOrdnung(_ ordnung: MerkOrdnung) {
        daten.merkOrdnung = ordnung.rawValue
        sichern()
    }

    /// Sofort speichern: Wer nach dem Überspringen die App beendet, soll sie nicht nochmal sehen.
    func setzeEinfuehrungGesehen() {
        daten.einfuehrungGesehen = true
        sichern()
    }

    /// Zustimmung zur Übertragung an Server und KI (Apple 5.1.2(i)); `false` widerruft sie.
    func setzeKiEinwilligung(_ ja: Bool) {
        daten.kiEinwilligung = ja ? AppDaten.kiEinwilligungVersion : 0
        sichern()
    }

    /// „Alle Daten löschen“ (nur nach Bestätigung aufrufen): Profile, Merkliste, Gelerntes,
    /// Einstellungen, Zustimmung und beiseitegelegte alte Dateien. Die Einführung kommt nicht wieder.
    func loescheAlles() {
        try? speicher.loescheAlles()
        var neu = AppDaten()
        neu.einfuehrungGesehen = true
        daten = neu
        sichern()
    }

    /// Rechtstexte aus dem App-Paket (`rechtliches.json`, dieselbe Datei wie auf dem Server).
    static let rechtstexte: Rechtstexte? = {
        guard let url = Bundle.main.url(forResource: "rechtliches", withExtension: "json"),
              let daten = try? Data(contentsOf: url) else { return nil }
        return try? Rechtstexte.laden(daten)
    }()

    private func sichern() {
        try? speicher.speichern(daten)
    }
}
