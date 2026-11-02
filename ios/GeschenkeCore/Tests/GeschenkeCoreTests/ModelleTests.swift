import Foundation
import XCTest
@testable import GeschenkeCore

final class ModelleTests: XCTestCase {
    func testKarteDekodiertSnakeCase() throws {
        let json = """
        {"id":"idee:x","art":"idee","titel":"Kniekissen","preis":null,"preis_von":15,"preis_bis":25,
         "bild_url":null,"emoji":"🧤","shop":"Amazon","link":"https://a","tags":["garten"]}
        """.data(using: .utf8)!
        let karte = try JSONDecoder().decode(Karte.self, from: json)
        XCTAssertEqual(karte.preisVon, 15)
        XCTAssertEqual(karte.preisBis, 25)
        XCTAssertNil(karte.bildURL)
        XCTAssertTrue(karte.istIdee)
    }

    func testKartenAntwortDekodiertTagLabels() throws {
        let json = """
        {"karten":[],"wird_duenn":true,"tag_labels":{"garten":"🌱 Garten"}}
        """.data(using: .utf8)!
        let antwort = try JSONDecoder().decode(KartenAntwort.self, from: json)
        XCTAssertTrue(antwort.wirdDuenn)
        XCTAssertEqual(antwort.tagLabels["garten"], "🌱 Garten")
    }

    func testProfilKodiertBudgetMax() throws {
        let daten = try JSONEncoder().encode(testProfil())
        let objekt = try JSONSerialization.jsonObject(with: daten) as! [String: Any]
        XCTAssertEqual(objekt["budget_max"] as? Double, 50)
        XCTAssertNil(objekt["budgetMax"])
    }

    func testPreisText() {
        XCTAssertEqual(testKarte().preisText, "34,90 €")
        let idee = Karte(id: "i", art: "idee", titel: "x", preis: nil, preisVon: 20, preisBis: 30,
                         bildURL: nil, emoji: "🎁", shop: "Amazon", link: "https://a", tags: [])
        XCTAssertEqual(idee.preisText, "ca. 20–30 €")
    }
}
