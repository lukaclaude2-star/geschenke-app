import Foundation
import GeschenkeCore

/// Der Kartenstapel beim Wischen: lädt nach, lernt aus Ja/Nein und merkt Ja-Karten.
@MainActor
final class KartenStapelModell: ObservableObject {
    static let nachladenAb = 3
    static let anzahl = 10

    @Published private(set) var stapel: [Karte] = []
    @Published private(set) var gewichtung: Gewichtung
    @Published private(set) var wirdDuenn = false
    @Published private(set) var laedt = false
    @Published private(set) var wachtAuf = false
    @Published private(set) var fehler: String?
    @Published private(set) var nichtsMehr = false

    let name: String?
    private(set) var profil: Profil
    private let profilID: UUID?
    private var gesehen: [String] = []
    private var entschieden: Set<String> = []
    private let api: GeschenkeAPI
    private weak var zustand: AppZustand?

    init(ziel: WischZiel, api: GeschenkeAPI) {
        name = ziel.name
        profil = ziel.profil
        profilID = ziel.profilID
        gewichtung = ziel.gewichtung
        self.api = api
    }

    func verbinde(_ zustand: AppZustand) {
        self.zustand = zustand
    }

    var duennHinweis: String {
        "Für \(name ?? "diese Person") wird's langsam dünn."
    }

    func nachladen() async {
        guard !laedt else { return }
        laedt = true
        fehler = nil
        let hinweis = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { self?.wachtAuf = true }
        }
        defer {
            hinweis.cancel()
            wachtAuf = false
        }
        do {
            let antwort = try await api.karten(profil: gewichtung.angewendet(auf: profil),
                                               gesehen: gesehen, anzahl: Self.anzahl)
            gewichtung.merkeLabels(antwort.tagLabels)
            let neu = antwort.karten.filter { karte in !stapel.contains { $0.id == karte.id } }
            gesehen += neu.map(\.id)
            stapel += neu
            wirdDuenn = antwort.wirdDuenn
            nichtsMehr = neu.isEmpty && stapel.isEmpty
        } catch {
            fehler = fehlerText(error)
        }
        laedt = false
    }

    func ja(_ karte: Karte) {
        // Doppeltipp/Wischen während der Animation: jede Karte lernt nur einmal.
        guard entschieden.insert(karte.id).inserted else { return }
        gewichtung.ja(tags: karte.tags)
        zustand?.merke(karte, fuer: name ?? "Ohne Namen")
        weg(karte)
    }

    func nein(_ karte: Karte) {
        guard entschieden.insert(karte.id).inserted else { return }
        gewichtung.nein(tags: karte.tags)
        weg(karte)
    }

    /// Während des Ziehens nur im Speicher ändern; gesichert wird beim Schließen (sichernJetzt).
    func setze(_ tag: String, auf wert: Double) {
        gewichtung.setze(tag, auf: wert)
    }

    func sichernJetzt() {
        sichern()
    }

    func zuruecksetzen() {
        gewichtung.zuruecksetzen()
        sichern()
    }

    /// Nach einer Änderung der Gewichtung: noch nicht gezeigte Karten verwerfen und neu holen.
    func neuSortieren() async {
        let verworfen = Set(stapel.map(\.id))
        gesehen.removeAll { verworfen.contains($0) }
        stapel = []
        await nachladen()
    }

    var ausschluesse: [Ausschluss] { profil.ausschluesse }

    private func weg(_ karte: Karte) {
        stapel.removeAll { $0.id == karte.id }
        sichern()
        if stapel.count <= Self.nachladenAb {
            Task { await nachladen() }
        }
    }

    private func sichern() {
        if let profilID { zustand?.aktualisiere(profilID, gewichtung: gewichtung) }
    }
}
