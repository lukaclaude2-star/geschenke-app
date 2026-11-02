import XCTest
@testable import GeschenkeCore

final class WischVerlaufTests: XCTestCase {
    private func schritt(_ id: String, person: Int = 0, ja: Bool = false) -> WischSchritt {
        WischSchritt(karte: testKarte(id), person: person, ja: ja,
                     gewichtungVorher: Gewichtung(profil: testProfil()), merkID: nil)
    }

    func testLeerKannNichtZurueck() {
        var verlauf = WischVerlauf()
        XCTAssertFalse(verlauf.kannZurueck)
        XCTAssertNil(verlauf.zurueck())
    }

    func testHoechstensZehnSchritte() {
        var verlauf = WischVerlauf()
        for i in 1...12 { verlauf.merke(schritt("k\(i)")) }
        var zurueck: [String] = []
        while let s = verlauf.zurueck() { zurueck.append(s.karte.id) }
        XCTAssertEqual(zurueck, (3...12).reversed().map { "k\($0)" })
        XCTAssertFalse(verlauf.kannZurueck)
    }

    func testZurueckGibtGewichtungVorher() {
        var g = Gewichtung(profil: testProfil())
        let vorher = g
        g.ja(tags: ["garten"])
        var verlauf = WischVerlauf()
        verlauf.merke(WischSchritt(karte: testKarte(), person: 1, ja: true, gewichtungVorher: vorher, merkID: UUID()))
        let s = verlauf.zurueck()
        XCTAssertEqual(s?.gewichtungVorher, vorher)
        XCTAssertNotEqual(s?.gewichtungVorher, g)
        XCTAssertEqual(s?.person, 1)
        XCTAssertNotNil(s?.merkID)
    }

    func testUebernimmtGeaendertesGewicht() {
        var g = Gewichtung(profil: testProfil([("garten", 1.0)]))
        g.ja(tags: ["garten"])
        g.uebernimm(profil: testProfil([("garten", 0.5)]))
        XCTAssertEqual(g.gewichte["garten"], 0.5)
    }

    func testUebernimmBehaeltGelerntesBeiGleichemGewicht() {
        var g = Gewichtung(profil: testProfil([("garten", 1.0)]))
        g.ja(tags: ["garten"])
        g.uebernimm(profil: testProfil([("garten", 1.0)]))
        XCTAssertEqual(g.gewichte["garten"]!, 1.15, accuracy: 0.0001)
    }
}

final class WischVerlaufVergessenTests: XCTestCase {
    func testVergissEntferntNurSchritteDerPerson() {
        var verlauf = WischVerlauf()
        let g = Gewichtung(profil: testProfil())
        verlauf.merke(WischSchritt(karte: testKarte("a"), person: 0, ja: true, gewichtungVorher: g, merkID: nil))
        verlauf.merke(WischSchritt(karte: testKarte("b"), person: 1, ja: true, gewichtungVorher: g, merkID: nil))
        verlauf.merke(WischSchritt(karte: testKarte("c"), person: 0, ja: false, gewichtungVorher: g, merkID: nil))
        verlauf.vergiss(person: 0)
        XCTAssertEqual(verlauf.zurueck()?.karte.id, "b")
        XCTAssertNil(verlauf.zurueck())
    }
}
