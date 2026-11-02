import Foundation
import GeschenkeCore

/// Eine Person im Stapel. Einzelsuche = eine Person, Sammelsuche = mehrere.
struct WischPerson {
    let name: String?
    let profil: Profil
    let profilID: UUID?
    var gewichtung: Gewichtung
    /// Nur wirklich gewischte Karten – geladene, aber nicht gewischte kommen wieder.
    var gesehen: [String]

    init(name: String?, profil: Profil, profilID: UUID?, gewichtung: Gewichtung, gesehen: [String] = []) {
        self.name = name
        self.profil = profil
        self.profilID = profilID
        self.gewichtung = gewichtung
        self.gesehen = gesehen
    }

    init(_ eintrag: GespeichertesProfil) {
        self.init(name: eintrag.name, profil: eintrag.profil, profilID: eintrag.id,
                  gewichtung: eintrag.gewichtung, gesehen: eintrag.gesehen)
    }
}

struct StapelKarte: Identifiable, Equatable {
    let karte: Karte
    /// Index in `KartenStapelModell.personen`.
    let person: Int
    var id: String { karte.id }
}

/// Der Kartenstapel beim Wischen: lädt nach, lernt aus Ja/Nein, merkt Ja-Karten und kann
/// die letzten Wischer zurücknehmen.
@MainActor
final class KartenStapelModell: ObservableObject {
    static let nachladenAb = 3
    static let anzahl = 10

    @Published private(set) var stapel: [StapelKarte] = []
    @Published private(set) var personen: [WischPerson]
    @Published private(set) var duenn: [Int] = []
    @Published private(set) var laedt = false
    @Published private(set) var wachtAuf = false
    @Published private(set) var fehler: String?
    @Published private(set) var kannZurueck = false

    private var verlauf = WischVerlauf()
    /// Zählt hoch, wenn neu sortiert wird – eine noch laufende Anfrage mit alter Gewichtung
    /// wird dann verworfen statt in den Stapel zu kommen.
    private var generation = 0
    private var entschieden: Set<String> = []
    private let api: GeschenkeAPI
    private weak var zustand: AppZustand?

    init(personen: [WischPerson], api: GeschenkeAPI) {
        self.personen = personen
        self.api = api
    }

    func verbinde(_ zustand: AppZustand) {
        self.zustand = zustand
    }

    var istSammel: Bool { personen.count > 1 }

    var titel: String {
        istSammel ? "Für \(personen.count) Personen" : (personen.first?.name ?? "Vorschläge")
    }

    func name(_ person: Int) -> String {
        personen[person].name ?? "Ohne Namen"
    }

    var duennHinweis: String? {
        guard !duenn.isEmpty else { return nil }
        if !istSammel { return "Für \(personen[0].name ?? "diese Person") wird's langsam dünn." }
        return "Für \(duenn.map { name($0) }.joined(separator: ", ")) wird's langsam dünn."
    }

    func nachladen() async {
        guard !laedt else { return }
        let meine = generation
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
        // Karten, die schon im Stapel liegen, nicht nochmal schicken lassen.
        let imStapel = stapel.map(\.karte.id)
        do {
            var neu: [StapelKarte]
            if istSammel {
                let anfrage = personen.enumerated().map { i, p in
                    SammelPerson(id: String(i), profil: p.gewichtung.angewendet(auf: p.profil),
                                 gesehen: p.gesehen + imStapel)
                }
                let antwort = try await api.sammelKarten(personen: anfrage,
                                                         anzahl: min(30, max(Self.anzahl, 2 * personen.count)))
                for i in personen.indices { personen[i].gewichtung.merkeLabels(antwort.tagLabels) }
                neu = antwort.karten.compactMap { k in
                    guard let i = Int(k.fuer), personen.indices.contains(i) else { return nil }
                    return StapelKarte(karte: k.karte, person: i)
                }
                duenn = antwort.duennFuer.compactMap { Int($0) }.filter { personen.indices.contains($0) }
            } else {
                let p = personen[0]
                let antwort = try await api.karten(profil: p.gewichtung.angewendet(auf: p.profil),
                                                   gesehen: p.gesehen + imStapel, anzahl: Self.anzahl)
                personen[0].gewichtung.merkeLabels(antwort.tagLabels)
                neu = antwort.karten.map { StapelKarte(karte: $0, person: 0) }
                duenn = antwort.wirdDuenn ? [0] : []
            }
            if meine == generation {
                neu = neu.filter { karte in !stapel.contains { $0.id == karte.id } && !entschieden.contains(karte.id) }
                stapel += neu
            }
        } catch {
            if meine == generation { fehler = fehlerText(error) }
        }
        laedt = false
        if meine != generation {
            // Während des Ladens wurde neu sortiert: mit der neuen Gewichtung nochmal.
            await nachladen()
        }
    }

    func ja(_ karte: StapelKarte) {
        // Doppeltipp/Wischen während der Animation: jede Karte zählt nur einmal.
        guard entschieden.insert(karte.id).inserted else { return }
        let vorher = personen[karte.person].gewichtung
        personen[karte.person].gewichtung.ja(tags: karte.karte.tags)
        let merkID = zustand?.merke(karte.karte, fuer: name(karte.person))
        verlauf.merke(WischSchritt(karte: karte.karte, person: karte.person, ja: true,
                                   gewichtungVorher: vorher, merkID: merkID))
        weg(karte)
    }

    func nein(_ karte: StapelKarte) {
        guard entschieden.insert(karte.id).inserted else { return }
        let vorher = personen[karte.person].gewichtung
        personen[karte.person].gewichtung.nein(tags: karte.karte.tags)
        verlauf.merke(WischSchritt(karte: karte.karte, person: karte.person, ja: false,
                                   gewichtungVorher: vorher, merkID: nil))
        weg(karte)
    }

    /// Nimmt den letzten Wischer komplett zurück: Karte, Gelerntes, Merkliste, Gesehen-Liste.
    func zurueck() {
        guard let schritt = verlauf.zurueck() else { return }
        let i = schritt.person
        personen[i].gewichtung = schritt.gewichtungVorher
        personen[i].gesehen.removeAll { $0 == schritt.karte.id }
        entschieden.remove(schritt.karte.id)
        if let merkID = schritt.merkID { zustand?.entferneMerk([merkID]) }
        stapel.removeAll { $0.id == schritt.karte.id }
        stapel.insert(StapelKarte(karte: schritt.karte, person: i), at: 0)
        kannZurueck = verlauf.kannZurueck
        sichern(i)
    }

    /// Während des Ziehens nur im Speicher ändern; gesichert wird beim Schließen (sichernJetzt).
    func setze(_ tag: String, auf wert: Double, person: Int) {
        personen[person].gewichtung.setze(tag, auf: wert)
        vergissVerlauf(person)
    }

    func sichernJetzt() {
        for i in personen.indices { sichern(i) }
    }

    func zuruecksetzen(person: Int) {
        personen[person].gewichtung.zuruecksetzen()
        vergissVerlauf(person)
        sichern(person)
    }

    /// Handänderungen gehen vor: Zurücknehmen darf sie nicht stillschweigend überschreiben.
    private func vergissVerlauf(_ person: Int) {
        verlauf.vergiss(person: person)
        kannZurueck = verlauf.kannZurueck
    }

    /// „Gesehene wieder zeigen“: alle bisher gewischten Karten dürfen wiederkommen.
    func gesehenZuruecksetzen() async {
        generation += 1
        for i in personen.indices { personen[i].gesehen = [] }
        entschieden = []
        verlauf = WischVerlauf()
        kannZurueck = false
        sichernJetzt()
        stapel = []
        await nachladen()
    }

    /// Nach einer Änderung der Gewichtung: noch nicht gezeigte Karten verwerfen und neu holen.
    func neuSortieren() async {
        generation += 1
        stapel = []
        await nachladen()
    }

    func ausschluesse(person: Int) -> [Ausschluss] {
        personen[person].profil.ausschluesse
    }

    private func weg(_ karte: StapelKarte) {
        stapel.removeAll { $0.id == karte.id }
        personen[karte.person].gesehen.append(karte.id)
        kannZurueck = verlauf.kannZurueck
        sichern(karte.person)
        if stapel.count <= Self.nachladenAb {
            Task { await nachladen() }
        }
    }

    private func sichern(_ person: Int) {
        let p = personen[person]
        if let id = p.profilID {
            zustand?.sichereGelerntes(id, gewichtung: p.gewichtung, gesehen: p.gesehen)
        }
    }
}
