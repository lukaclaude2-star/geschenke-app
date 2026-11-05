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

    /// `anzahl` Karten mit gleichen Tags, IDs `<praefix>0`, `<praefix>1` …
    private func stapel(_ anzahl: Int, _ praefix: String = "k", tags: [String]) -> [Karte] {
        var karten: [Karte] = []
        for i in 0..<anzahl {
            karten.append(testKarte(praefix + String(i), tags: tags))
        }
        return karten
    }

    func testLeereListeKeinTreffer() {
        XCTAssertEqual(richtigGuteTreffer([], gewichtung: gewichtung()), [])
    }

    func testZehnKartenGenauEinTrefferMitHoechsterPunktzahl() {
        var karten = stapel(10, tags: ["garten"])
        for i in [1, 3, 5, 7, 9] {
            karten[i] = testKarte("k" + String(i), tags: ["krimis"])
        }
        karten[6] = testKarte("k6", tags: ["garten", "krimis"])  // 1,5 statt 1,0
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung()), ["k6"])
    }

    func testAnteilBestimmtAnzahl() {
        var karten = stapel(20, tags: ["krimis"])
        karten[3] = testKarte("k3", tags: ["tee"])
        karten[15] = testKarte("k15", tags: ["garten", "tee"])
        karten[9] = testKarte("k9", tags: ["garten"])
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung()), ["k15", "k3"])
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung(), anteil: 0.15), ["k15", "k3", "k9"])
    }

    func testDoppelteTagsZaehlenEinmal() {
        var karten = stapel(10, tags: ["garten"])
        karten[2] = testKarte("k2", tags: ["krimis", "krimis", "krimis"])  // 0,5, nicht 1,5
        karten[7] = testKarte("k7", tags: ["garten", "krimis"])
        XCTAssertEqual(richtigGuteTreffer(karten, gewichtung: gewichtung()), ["k7"])
    }

    func testGleichstandNimmtVordereKarte() {
        XCTAssertEqual(richtigGuteTreffer(stapel(10, tags: ["garten"]), gewichtung: gewichtung()), ["k0"])
    }

    func testOhnePositivePunktzahlNieTreffer() {
        var g = gewichtung()
        g.setze("garten", auf: 0)
        XCTAssertEqual(richtigGuteTreffer(stapel(10, "u", tags: ["gaming"]), gewichtung: g), [])
        XCTAssertEqual(richtigGuteTreffer(stapel(10, "n", tags: ["garten"]), gewichtung: g), [])
        XCTAssertEqual(richtigGuteTreffer(stapel(10, "o", tags: []), gewichtung: g), [])
        // Nur eine Karte hat Punkte: Sie ist Treffer, auch wenn der Anteil mehr erlauben würde.
        var gemischt = stapel(20, "m", tags: ["gaming"])
        gemischt[12] = testKarte("m12", tags: ["krimis"])
        XCTAssertEqual(richtigGuteTreffer(gemischt, gewichtung: g), ["m12"])
    }

    func testWenigerAlsFuenfKarten() {
        let g = gewichtung()
        for anzahl in 1...4 {
            let treffer = richtigGuteTreffer(stapel(anzahl, tags: ["tee"]), gewichtung: g)
            XCTAssertLessThanOrEqual(treffer.count, 1, "\(anzahl) Karten")
            XCTAssertTrue(treffer.isEmpty, "\(anzahl) Karten")
        }
        XCTAssertEqual(richtigGuteTreffer(stapel(4, tags: ["gaming"]), gewichtung: g), [])
    }

    func testFuenfKartenMindestensEinTreffer() {
        var karten = stapel(5, tags: ["krimis"])
        karten[4] = testKarte("k4", tags: ["tee"])
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
