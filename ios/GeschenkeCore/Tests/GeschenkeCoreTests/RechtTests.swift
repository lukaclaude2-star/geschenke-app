import Foundation
import XCTest
@testable import GeschenkeCore

/// App Store: Rechtstexte, KI-Zustimmung, Anzeige, sichere Links, alles löschen (Plan 2026-11-05, Task 5).
final class RechtTests: XCTestCase {
    /// Die echte Datei aus dem Repo, dieselbe, die die App bündelt.
    private func echteTexte() throws -> Rechtstexte {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        let daten = try Data(contentsOf: url.appendingPathComponent("rechtliches/rechtliches.json"))
        return try Rechtstexte.laden(daten)
    }

    func testEchteDateiHatAlleDokumente() throws {
        let texte = try echteTexte()
        XCTAssertEqual(Set(texte.dokumente.map(\.id)),
                       ["impressum", "datenschutz", "nutzung", "support", "lizenzen"])
    }

    func testPlatzhalterWerdenErsetzt() throws {
        let texte = try echteTexte()
        let impressum = try XCTUnwrap(texte.dokument("impressum"))
        let alles = impressum.abschnitte.flatMap(\.absaetze).joined(separator: " ")
        XCTAssertFalse(alles.contains("{{"))
        XCTAssertTrue(alles.contains(texte.angaben["name"] ?? "fehlt"))
    }

    func testStandWirdErsetzt() throws {
        let json = """
        {"stand": "05.11.2026", "angaben": {"name": "Max"}, "dokumente": [
          {"id": "a", "titel": "Titel {{name}}", "abschnitte": [{"ueberschrift": null, "absaetze": ["Stand {{stand}}, {{unbekannt}}"]}]}]}
        """
        let texte = try Rechtstexte.laden(Data(json.utf8))
        let dokument = try XCTUnwrap(texte.dokument("a"))
        XCTAssertEqual(dokument.titel, "Titel Max")
        XCTAssertEqual(dokument.abschnitte[0].absaetze[0], "Stand 05.11.2026, {{unbekannt}}")
        XCTAssertNil(dokument.abschnitte[0].ueberschrift)
        XCTAssertNil(texte.dokument("gibtsnicht"))
    }

    func testOffeneAngaben() throws {
        let json = """
        {"stand": "", "angaben": {"name": "[Vor- und Nachname]", "email": "max@example.org"}, "dokumente": []}
        """
        XCTAssertEqual(try Rechtstexte.laden(Data(json.utf8)).offeneAngaben, ["name"])
        // Im Repo stehen nur Platzhalter; der iOS-Build füllt sie aus dem Secret IMPRESSUM_JSON
        // und bricht ab, wenn einer offen bleibt. Hier: kein zusätzlicher Platzhalter dazugekommen.
        XCTAssertEqual(Set(try echteTexte().offeneAngaben), ["name", "strasse", "plz_ort", "email", "telefon"])
    }

    func testAlteDatenOhneZustimmung() throws {
        let alt = """
        {"profile": [], "merkliste": [], "schriftgroesse": "gross", "einfuehrungGesehen": true}
        """
        let daten = try JSONDecoder().decode(AppDaten.self, from: Data(alt.utf8))
        XCTAssertFalse(daten.hatKiEinwilligung)
        XCTAssertEqual(daten.schriftgroesse, "gross")
    }

    func testZustimmungRundreise() throws {
        var daten = AppDaten()
        XCTAssertFalse(daten.hatKiEinwilligung)
        daten.kiEinwilligung = AppDaten.kiEinwilligungVersion
        let geladen = try JSONDecoder().decode(AppDaten.self, from: JSONEncoder().encode(daten))
        XCTAssertTrue(geladen.hatKiEinwilligung)
    }

    func testAlteZustimmungsVersionGiltNicht() {
        var daten = AppDaten()
        daten.kiEinwilligung = AppDaten.kiEinwilligungVersion - 1
        XCTAssertFalse(daten.hatKiEinwilligung)
    }

    func testKarteOhneAnzeigeFeld() throws {
        let json = """
        {"id": "a", "art": "produkt", "titel": "T", "preis": 5, "bild_url": null, "shop": "S",
         "link": "https://x.de/a", "tags": []}
        """
        let karte = try JSONDecoder().decode(Karte.self, from: Data(json.utf8))
        XCTAssertFalse(karte.istAnzeige)
    }

    func testKarteMitAnzeige() throws {
        let json = """
        {"id": "a", "art": "produkt", "titel": "T", "preis": 5, "bild_url": null, "shop": "S",
         "link": "https://x.de/a", "tags": [], "anzeige": true}
        """
        XCTAssertTrue(try JSONDecoder().decode(Karte.self, from: Data(json.utf8)).istAnzeige)
    }

    private func karte(link: String) -> Karte {
        Karte(id: "a", art: "produkt", titel: "T", preis: 1, preisVon: nil, preisBis: nil, bildURL: nil,
              emoji: nil, shop: "S", link: link, tags: [])
    }

    func testSichererLink() {
        XCTAssertEqual(karte(link: "https://x.de/p?a=1").sichererLink?.absoluteString, "https://x.de/p?a=1")
        XCTAssertNotNil(karte(link: "http://x.de/p").sichererLink)
        XCTAssertNil(karte(link: "javascript:alert(1)").sichererLink)
        XCTAssertNil(karte(link: "tel:123").sichererLink)
        XCTAssertNil(karte(link: "").sichererLink)
        XCTAssertNil(karte(link: "https://").sichererLink)
    }

    func testLoescheAlles() throws {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let datei = ordner.appendingPathComponent("appdaten.json")
        let speicher = AppDatenSpeicher(datei: datei)
        try speicher.speichern(AppDaten())
        try Data("alt".utf8).write(to: ordner.appendingPathComponent("appdaten.kaputt-1.json"))
        try Data("fremd".utf8).write(to: ordner.appendingPathComponent("andere.json"))
        try speicher.loescheAlles()
        let uebrig = try FileManager.default.contentsOfDirectory(atPath: ordner.path)
        XCTAssertEqual(uebrig, ["andere.json"])
        XCTAssertTrue(speicher.laden().profile.isEmpty)
    }

    func testLoescheAllesOhneDatei() throws {
        let datei = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        XCTAssertNoThrow(try AppDatenSpeicher(datei: datei).loescheAlles())
    }
}
