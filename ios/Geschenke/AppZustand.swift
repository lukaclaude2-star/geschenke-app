import Foundation
import GeschenkeCore

/// Hält Profile und Merkliste und speichert jede Änderung sofort – nur auf dem Handy.
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

    func loescheProfile(_ ids: [UUID]) {
        daten.profile.removeAll { ids.contains($0.id) }
        sichern()
    }

    func merke(_ karte: Karte, fuer: String) {
        guard !daten.merkliste.contains(where: { $0.karte.id == karte.id && $0.fuer == fuer }) else { return }
        daten.merkliste.insert(MerkEintrag(karte: karte, fuer: fuer), at: 0)
        sichern()
    }

    func entferneMerk(_ ids: [UUID]) {
        daten.merkliste.removeAll { ids.contains($0.id) }
        sichern()
    }

    private func sichern() {
        try? speicher.speichern(daten)
    }
}
