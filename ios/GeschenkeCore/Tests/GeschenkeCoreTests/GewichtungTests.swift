import XCTest
@testable import GeschenkeCore

final class GewichtungTests: XCTestCase {
    func testJaErhoehtUmJaSchritt() {
        var g = Gewichtung(profil: testProfil())
        g.ja(tags: ["garten"])
        XCTAssertEqual(g.gewichte["garten"]!, 1.15, accuracy: 0.0001)
    }

    func testNeinSenktSchwaecherAlsJaErhoeht() {
        var g = Gewichtung(profil: testProfil())
        g.nein(tags: ["garten"])
        XCTAssertEqual(g.gewichte["garten"]!, 0.95, accuracy: 0.0001)
    }

    func testNeinLaesstUnbekannteTagsWeg() {
        var g = Gewichtung(profil: testProfil())
        g.nein(tags: ["gaming"])
        XCTAssertNil(g.gewichte["gaming"])
    }

    func testJaNachVielNeinZaehltMehr() {
        var g = Gewichtung(profil: testProfil([("garten", 1.0), ("krimis", 1.0)]))
        for _ in 0..<19 { g.nein(tags: ["krimis"]) }
        g.ja(tags: ["garten"])
        XCTAssertEqual(g.gewichte["garten"]!, 1.0 + 0.15 * (1 + 2 * 1.0), accuracy: 0.0001)
    }

    func testNeinAnteilZaehltNurLetzte20() {
        var g = Gewichtung(profil: testProfil([("garten", 1.0), ("krimis", 1.0)]))
        for _ in 0..<10 { g.nein(tags: ["krimis"]) }
        for _ in 0..<10 { g.ja(tags: ["krimis"]) }
        let vorher = g.gewichte["garten"]!
        g.ja(tags: ["garten"])
        // letzte 20: 10× Nein, 10× Ja → Anteil 0.5
        XCTAssertEqual(g.gewichte["garten"]! - vorher, 0.15 * (1 + 2 * 0.5), accuracy: 0.0001)
    }

    func testUnterFuenfEntscheidungenKeinVerstaerker() {
        var g = Gewichtung(profil: testProfil([("garten", 1.0), ("krimis", 1.0)]))
        for _ in 0..<3 { g.nein(tags: ["krimis"]) }
        g.ja(tags: ["garten"])
        XCTAssertEqual(g.gewichte["garten"]!, 1.15, accuracy: 0.0001)
    }

    func testUnbekannterTagWirdBeiJaGelernt() {
        var g = Gewichtung(profil: testProfil())
        g.ja(tags: ["hund"])
        XCTAssertEqual(g.gewichte["hund"]!, 0.3, accuracy: 0.0001)
    }

    func testGewichteBleibenImBereich() {
        var g = Gewichtung(profil: testProfil([("garten", 1.95), ("krimis", 0.02)]))
        g.ja(tags: ["garten"])
        g.nein(tags: ["krimis"])
        g.setze("lesen", auf: 5)
        XCTAssertEqual(g.gewichte["garten"]!, 2.0)
        XCTAssertEqual(g.gewichte["krimis"]!, 0.0)
        XCTAssertEqual(g.gewichte["lesen"]!, 2.0)
    }

    func testSetzeUeberschreibt() {
        var g = Gewichtung(profil: testProfil())
        g.setze("garten", auf: 0.4)
        XCTAssertEqual(g.gewichte["garten"]!, 0.4, accuracy: 0.0001)
    }

    func testZuruecksetzenStelltStartHer() {
        var g = Gewichtung(profil: testProfil())
        g.ja(tags: ["garten", "hund"])
        g.zuruecksetzen()
        XCTAssertEqual(g.gewichte, ["garten": 1.0])
        XCTAssertTrue(g.verlauf.isEmpty)
    }

    func testAngewendetErsetztGewichteUndErgaenztGelernte() {
        var g = Gewichtung(profil: testProfil())
        g.merkeLabels(["hund": "🐶 Hund"])
        g.ja(tags: ["garten", "hund"])
        let p = g.angewendet(auf: testProfil())
        XCTAssertEqual(p.wuensche.first { $0.tag == "garten" }!.gewicht, 1.15, accuracy: 0.0001)
        XCTAssertEqual(p.wuensche.first { $0.tag == "hund" }?.label, "🐶 Hund")
        XCTAssertEqual(p.ausschluesse.count, 1)
    }

    func testNeueWuenscheAusProfilAenderungKommenDazu() {
        var g = Gewichtung(profil: testProfil())
        g.ja(tags: ["garten"])
        g.uebernimm(profil: testProfil([("garten", 1.0), ("hund", 1.2)]))
        XCTAssertEqual(g.gewichte["garten"]!, 1.15, accuracy: 0.0001)  // gelernt bleibt
        XCTAssertEqual(g.gewichte["hund"]!, 1.2, accuracy: 0.0001)     // neu aus Profil
    }

    func testStufe() {
        XCTAssertEqual(Gewichtung.stufe(0.3), "schwach")
        XCTAssertEqual(Gewichtung.stufe(1.0), "normal")
        XCTAssertEqual(Gewichtung.stufe(1.6), "stark")
    }
}
