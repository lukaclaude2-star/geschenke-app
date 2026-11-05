import Foundation
import XCTest
@testable import GeschenkeCore

final class MerklisteTests: XCTestCase {
    private func eintrag(_ id: String, fuer: String = "Mama", tags: [String] = ["garten"],
                         gekauft: Bool = false) -> MerkEintrag {
        MerkEintrag(karte: testKarte(id, tags: tags), fuer: fuer, gekauft: gekauft)
    }

    func testKategorieAusErstemBekanntenTag() {
        XCTAssertEqual(kategorie(testKarte(tags: ["umzug", "grillen", "wein"])), "Küche & Kochen")
        XCTAssertEqual(kategorie(testKarte(tags: ["whisky"])), "Genuss & Getränke")
    }

    func testSonstigesOhneBekanntenTag() {
        XCTAssertEqual(kategorie(testKarte(tags: ["umzug"])), "Sonstiges")
        XCTAssertEqual(kategorie(testKarte(tags: [])), "Sonstiges")
    }

    func testKategorieNamenOhneEmoji() {
        for name in bereichNamen.values {
            XCTAssertTrue(name.first?.isLetter == true, name)
        }
        XCTAssertEqual(bereichReihenfolge.count, bereichNamen.count)
    }

    func testGruppenNachPersonInReihenfolgeDesAuftauchens() {
        let liste = [eintrag("a", fuer: "Mama"), eintrag("b", fuer: "Papa"), eintrag("c", fuer: "Mama")]
        let gruppen = merkGruppen(liste, ordnung: .person)
        XCTAssertEqual(gruppen.map(\.titel), ["Mama", "Papa"])
        XCTAssertEqual(gruppen[0].eintraege.map(\.karte.id), ["a", "c"])
    }

    func testGruppenNachKategorieGroessteZuerstSonstigesAmEnde() {
        let liste = [eintrag("a", tags: ["umzug"]), eintrag("b", tags: ["umzug"]), eintrag("c", tags: ["umzug"]),
                     eintrag("d", tags: ["wein"]),
                     eintrag("e", tags: ["grillen"]), eintrag("f", tags: ["kochen"])]
        let gruppen = merkGruppen(liste, ordnung: .kategorie)
        XCTAssertEqual(gruppen.map(\.titel), ["Küche & Kochen", "Genuss & Getränke", "Sonstiges"])
        XCTAssertEqual(gruppen[0].eintraege.map(\.karte.id), ["e", "f"])
    }

    func testGleichGrosseKategorienInVokabularReihenfolge() {
        let liste = [eintrag("a", tags: ["wein"]), eintrag("b", tags: ["grillen"])]
        XCTAssertEqual(merkGruppen(liste, ordnung: .kategorie).map(\.titel), ["Küche & Kochen", "Genuss & Getränke"])
    }

    func testGekaufteRutschenInDerGruppeNachUnten() {
        let liste = [eintrag("a", gekauft: true), eintrag("b"), eintrag("c", gekauft: true), eintrag("d")]
        let ids = merkGruppen(liste, ordnung: .person)[0].eintraege.map(\.karte.id)
        XCTAssertEqual(ids, ["b", "d", "a", "c"])
    }

    func testLeereListeGibtKeineGruppen() {
        XCTAssertTrue(merkGruppen([], ordnung: .person).isEmpty)
        XCTAssertTrue(merkGruppen([], ordnung: .kategorie).isEmpty)
    }

    func testTeilTextEnthaeltTitelPreisUndLink() {
        let text = teilText(fuer: "Mama", eintraege: [eintrag("a"), eintrag("b", gekauft: true)])
        XCTAssertTrue(text.hasPrefix("Geschenkideen für Mama"), text)
        XCTAssertTrue(text.contains("Hochbeet"), text)
        XCTAssertTrue(text.contains("34,90 €"), text)
        XCTAssertTrue(text.contains("https://x/a"), text)
        // Schon Gekauftes verrät man nicht weiter
        XCTAssertEqual(text.components(separatedBy: "Hochbeet").count - 1, 1, text)
    }

    func testMerkOrdnungAusRohwert() {
        XCTAssertEqual(MerkOrdnung.aus("kategorie"), .kategorie)
        XCTAssertEqual(MerkOrdnung.aus("quatsch"), .person)
        XCTAssertEqual(MerkOrdnung.allCases.map(\.titel), ["Personen", "Kategorien"])
    }

    func testAlteDatenOhneNeueFelder() throws {
        let alt = """
        {"profile":[],"merkliste":[{"id":"\(UUID().uuidString)","fuer":"Mama","datum":0,
          "karte":{"id":"a","art":"produkt","titel":"Hochbeet","preis":34.9,"shop":"Shop",
                   "link":"https://x/a","tags":["garten"]}}],
         "design":"zuhause","schriftgroesse":"normal"}
        """
        let daten = try JSONDecoder().decode(AppDaten.self, from: Data(alt.utf8))
        XCTAssertEqual(daten.merkliste.count, 1)
        XCTAssertFalse(daten.merkliste[0].gekauft)
        XCTAssertEqual(daten.merkOrdnung, "person")
        XCTAssertFalse(daten.einfuehrungGesehen)
    }

    func testEinfuehrungGesehenRundreise() throws {
        let datei = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let speicher = AppDatenSpeicher(datei: datei)
        var daten = AppDaten()
        daten.einfuehrungGesehen = true
        daten.merkOrdnung = "kategorie"
        daten.merkliste = [eintrag("a", gekauft: true)]
        try speicher.speichern(daten)
        let geladen = AppDatenSpeicher(datei: datei).laden()
        XCTAssertTrue(geladen.einfuehrungGesehen)
        XCTAssertEqual(geladen.merkOrdnung, "kategorie")
        XCTAssertTrue(geladen.merkliste[0].gekauft)
    }
}
