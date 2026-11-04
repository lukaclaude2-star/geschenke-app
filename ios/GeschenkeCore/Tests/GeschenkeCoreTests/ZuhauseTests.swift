import XCTest
@testable import GeschenkeCore

final class ZuhauseTests: XCTestCase {
    func testErscheinungAusRohwert() {
        XCTAssertEqual(Erscheinung.aus("abendlicht"), .abendlicht)
        XCTAssertEqual(Erscheinung.aus("hell"), .hell)
        XCTAssertEqual(Erscheinung.aus("quatsch"), .automatisch)
        XCTAssertEqual(Erscheinung.allCases.map(\.titel), ["Automatisch", "Hell", "Abendlicht"])
    }

    func testBegruessung() {
        XCTAssertEqual(begruessung(stunde: 4), "guten abend.")
        XCTAssertEqual(begruessung(stunde: 5), "guten morgen.")
        XCTAssertEqual(begruessung(stunde: 10), "guten morgen.")
        XCTAssertEqual(begruessung(stunde: 11), "guten tag.")
        XCTAssertEqual(begruessung(stunde: 17), "guten tag.")
        XCTAssertEqual(begruessung(stunde: 18), "guten abend.")
        XCTAssertEqual(begruessung(stunde: 0), "guten abend.")
    }

    func testAuspackTempo() {
        XCTAssertEqual(AuspackTempo.allCases.map(\.rawValue), ["langsam", "normal", "schnell", "aus"])
        XCTAssertEqual(AuspackTempo.allCases.map(\.titel), ["langsam", "normal", "schnell", "aus"])
        XCTAssertEqual(AuspackTempo.langsam.dauer, 1.3, accuracy: 0.0001)
        XCTAssertEqual(AuspackTempo.normal.dauer, 0.8, accuracy: 0.0001)
        XCTAssertEqual(AuspackTempo.schnell.dauer, 0.45, accuracy: 0.0001)
        let aus: AuspackTempo = .aus
        XCTAssertEqual(aus.dauer, 0)
    }

    func testAuspackTempoAusRohwert() {
        XCTAssertEqual(AuspackTempo.aus("schnell"), .schnell)
        XCTAssertEqual(AuspackTempo.aus("aus"), AuspackTempo.aus)
        XCTAssertEqual(AuspackTempo.aus("quatsch"), .normal)
        XCTAssertEqual(AuspackTempo.aus(""), .normal)
    }

    // MARK: Richtig gute Treffer

    private func gewichtung() -> Gewichtung {
        Gewichtung(profil: testProfil([("garten", 1.0), ("krimis", 0.5), ("tee", 1.6)]))
    }

    func testLeereListeKeinTreffer() {
        XCTAssertEqual(richtigGuteTreffer([], gewichtung: gewichtung()), [])
    }

    func testZehnKartenGenauEinTrefferMitHoechsterPunktzahl() {
        var karten = (0..<10).map { testKarte("k\($0)", tags: $0 % 2 == 0 ? ["garten"] : ["krimis"]) }
        karten[6] = testKarte("k6", tags: ["garten", "krimis"])  // 1,5 statt 1,0
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung()), ["k6"])
    }

    func testAnteilBestimmtAnzahl() {
        var karten = (0..<20).map { testKarte("k\($0)", tags: ["krimis"]) }
        karten[3] = testKarte("k3", tags: ["tee"])
        karten[15] = testKarte("k15", tags: ["garten", "tee"])
        karten[9] = testKarte("k9", tags: ["garten"])
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung()), ["k15", "k3"])
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung(), anteil: 0.15), ["k15", "k3", "k9"])
    }

    func testDoppelteTagsZaehlenEinmal() {
        var karten = (0..<10).map { testKarte("k\($0)", tags: ["garten"]) }
        karten[2] = testKarte("k2", tags: ["krimis", "krimis", "krimis"])  // 0,5, nicht 1,5
        karten[7] = testKarte("k7", tags: ["garten", "krimis"])
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung()), ["k7"])
    }

    func testGleichstandNimmtVordereKarte() {
        let karten = (0..<10).map { testKarte("k\($0)", tags: ["garten"]) }
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung()), ["k0"])
    }

    func testOhnePositivePunktzahlNieTreffer() {
        var g = gewichtung()
        g.setze("garten", auf: 0)
        let unbekannt = (0..<10).map { testKarte("u\($0)", tags: ["gaming"]) }
        XCTAssertEqual(richtigGuteTreffer(unbekannt, gewichtung: g), [])
        let nullGewicht = (0..<10).map { testKarte("n\($0)", tags: ["garten"]) }
        XCTAssertEqual(richtigGuteTreffer(nullGewicht, gewichtung: g), [])
        let ohneTags = (0..<10).map { testKarte("o\($0)", tags: []) }
        XCTAssertEqual(richtigGuteTreffer(ohneTags, gewichtung: g), [])
        // Nur eine Karte hat Punkte: Sie ist Treffer, auch wenn der Anteil mehr erlauben würde.
        var gemischt = (0..<20).map { testKarte("m\($0)", tags: ["gaming"]) }
        gemischt[12] = testKarte("m12", tags: ["krimis"])
        XCTAssertEqual(richtigGuteTreffer(gemischt, gewichtung: g), ["m12"])
    }

    func testWenigerAlsFuenfKarten() {
        let g = gewichtung()
        for anzahl in 1...4 {
            let karten = (0..<anzahl).map { testKarte("k\($0)", tags: ["tee"]) }
            let treffer = richtigGuteTreffer(karten, gewichtung: g)
            XCTAssertLessThanOrEqual(treffer.count, 1, "\(anzahl) Karten")
            XCTAssertTrue(treffer.isEmpty, "\(anzahl) Karten")
        }
        let ohnePunkte = (0..<4).map { testKarte("k\($0)", tags: ["gaming"]) }
        XCTAssertEqual(richtigGuteTreffer(ohnePunkte, gewichtung: g), [])
    }

    func testFuenfKartenMindestensEinTreffer() {
        let karten = (0..<5).map { testKarte("k\($0)", tags: $0 == 4 ? ["tee"] : ["krimis"]) }
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung()), ["k4"])
    }

    // MARK: Passt, weil …

    private func gewichtungMitLabels() -> Gewichtung {
        let profil = Profil(zusammenfassung: "Mama",
                            wuensche: [Wunsch(tag: "garten", label: "Gartenarbeit", gewicht: 1.0),
                                       Wunsch(tag: "tee", label: "Tee am Abend", gewicht: 1.4),
                                       Wunsch(tag: "krimis", label: "Krimis", gewicht: 0.6)],
                            ausschluesse: [], budgetMax: 50)
        return Gewichtung(profil: profil)
    }

    func testPasstWeilNimmtHoechstesGewicht() {
        let g = gewichtungMitLabels()
        XCTAssertEqual(passtWeil(testKarte("a", tags: ["garten", "tee", "krimis"]), gewichtung: g), "Tee am Abend")
        XCTAssertEqual(passtWeil(testKarte("b", tags: ["krimis", "gaming"]), gewichtung: g), "Krimis")
    }

    func testPasstWeilNilOhneTreffer() {
        var g = gewichtungMitLabels()
        XCTAssertNil(passtWeil(testKarte("a", tags: ["gaming"]), gewichtung: g))
        XCTAssertNil(passtWeil(testKarte("b", tags: []), gewichtung: g))
        g.setze("garten", auf: 0)
        XCTAssertNil(passtWeil(testKarte("c", tags: ["garten"]), gewichtung: g))
    }

    func testPasstWeilOhneLabelNimmtTag() {
        var g = gewichtungMitLabels()
        g.ja(tags: ["lesen"])  // neu gelernt, noch ohne Label
        XCTAssertEqual(passtWeil(testKarte("a", tags: ["lesen"]), gewichtung: g), "lesen")
    }
}
