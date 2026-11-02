import Foundation
import XCTest
@testable import GeschenkeCore

final class Runde3Tests: XCTestCase {
    private var kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return k
    }()

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int, stunde: Int = 15) -> Date {
        kalender.date(from: DateComponents(year: jahr, month: monat, day: tag, hour: stunde))!
    }

    private func profil(_ name: String, _ geburtstag: Geburtstag?) -> GespeichertesProfil {
        let roh = Profil(zusammenfassung: name, wuensche: [], ausschluesse: [], budgetMax: nil)
        var p = GespeichertesProfil(name: name, profil: roh, gewichtung: Gewichtung(profil: roh))
        p.geburtstag = geburtstag
        return p
    }

    func testAlteDatenOhneNeueFelder() throws {
        let daten = try JSONDecoder().decode(AppDaten.self, from: v1JSON)
        XCTAssertNil(daten.profile.first?.geburtstag)
        XCTAssertEqual(daten.schriftgroesse, "normal")
        XCTAssertNil(daten.merkliste.first?.karte.beispielbild)
    }

    func testNeueFelderUeberlebenSpeichern() throws {
        var daten = AppDaten()
        daten.schriftgroesse = "gross"
        daten.profile = [profil("Mama", Geburtstag(tag: 14, monat: 11))]
        let zurueck = try JSONDecoder().decode(AppDaten.self, from: JSONEncoder().encode(daten))
        XCTAssertEqual(zurueck.schriftgroesse, "gross")
        XCTAssertEqual(zurueck.profile.first?.geburtstag, Geburtstag(tag: 14, monat: 11))
    }

    func testKarteMitBeispielbild() throws {
        let json = """
        {"id":"idee:x","art":"idee","titel":"Headset","preis":null,"bild_url":"https://p/1.jpg",
         "shop":"Amazon","link":"https://a","tags":[],"beispielbild":true}
        """.data(using: .utf8)!
        let karte = try JSONDecoder().decode(Karte.self, from: json)
        XCTAssertTrue(karte.istBeispielbild)
    }

    func testWeihnachtenOhneProfile() {
        XCTAssertEqual(naechsterAnlass(heute: datum(2026, 11, 2), profile: [], kalender: kalender),
                       Anlass(art: .weihnachten, tage: 52))
        XCTAssertEqual(naechsterAnlass(heute: datum(2026, 12, 24, stunde: 23), profile: [], kalender: kalender).tage, 0)
        XCTAssertEqual(naechsterAnlass(heute: datum(2026, 12, 25), profile: [], kalender: kalender).tage, 364)
    }

    func testGeburtstagVorWeihnachten() {
        let mama = profil("Mama", Geburtstag(tag: 14, monat: 11))
        let papa = profil("Papa", Geburtstag(tag: 1, monat: 3))
        let ohne = profil("Lena", nil)
        XCTAssertEqual(naechsterAnlass(heute: datum(2026, 11, 2), profile: [papa, ohne, mama], kalender: kalender),
                       Anlass(art: .geburtstag(profilID: mama.id, name: "Mama"), tage: 12))
    }

    func testGleichstandGewinntGeburtstag() {
        let kind = profil("Jesus", Geburtstag(tag: 24, monat: 12))
        XCTAssertEqual(naechsterAnlass(heute: datum(2026, 12, 1), profile: [kind], kalender: kalender).art,
                       .geburtstag(profilID: kind.id, name: "Jesus"))
    }

    func testGeburtstagHeuteUndSchaltjahr() {
        XCTAssertEqual(tageBis(tag: 2, monat: 11, heute: datum(2026, 11, 2), kalender: kalender), 0)
        XCTAssertEqual(tageBis(tag: 1, monat: 11, heute: datum(2026, 11, 2), kalender: kalender), 364)
        // 29.02. zählt in Nicht-Schaltjahren als 28.02.
        XCTAssertEqual(tageBis(tag: 29, monat: 2, heute: datum(2027, 2, 1), kalender: kalender), 27)
        XCTAssertEqual(tageBis(tag: 29, monat: 2, heute: datum(2028, 2, 1), kalender: kalender), 28)
    }

    func testSchriftstufen() {
        XCTAssertEqual(Schriftstufe.allCases.map(\.rawValue), ["klein", "normal", "gross", "sehrGross"])
        XCTAssertEqual(Schriftstufe(rawValue: "gross")?.titel, "Groß")
        XCTAssertEqual(Schriftstufe.aus("quatsch"), .normal)
    }
}
