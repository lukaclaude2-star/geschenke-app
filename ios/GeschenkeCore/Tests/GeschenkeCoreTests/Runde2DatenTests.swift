import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import GeschenkeCore

/// Genau das Format, das v1 auf den Handys gespeichert hat.
let v1JSON = """
{"profile":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Oma",
 "profil":{"zusammenfassung":"Oma","wuensche":[{"tag":"garten","label":"Garten","gewicht":1}],
           "ausschluesse":[{"schluessel":"farbe:schwarz","label":"Schwarz"}],"budget_max":50},
 "gewichtung":{"gewichte":{"garten":1.15},"start":{"garten":1},"verlauf":[true],"labels":{"garten":"Garten"}}}],
 "merkliste":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","fuer":"Oma","datum":700000000,
   "karte":{"id":"a","art":"produkt","titel":"Hochbeet","preis":34.9,"bild_url":"https://x/b.jpg",
            "shop":"Shop","link":"https://x/a","tags":["garten"]}}]}
""".data(using: .utf8)!

final class Runde2DatenTests: XCTestCase {
    func testV1DatenLadenOhneVerlust() throws {
        let daten = try JSONDecoder().decode(AppDaten.self, from: v1JSON)
        XCTAssertEqual(daten.profile.first?.name, "Oma")
        XCTAssertEqual(daten.profile.first?.gesehen, [])
        XCTAssertNil(daten.profile.first?.profil.budgetMin)
        XCTAssertEqual(daten.profile.first?.profil.budgetMax, 50)
        XCTAssertEqual(daten.profile.first?.gewichtung.gewichte["garten"], 1.15)
        XCTAssertEqual(daten.merkliste.first?.karte.id, "a")
    }

    func testSpeicherLaedtV1DateiOhneKaputtKopie() throws {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let datei = ordner.appendingPathComponent("appdaten.json")
        try v1JSON.write(to: datei)
        let speicher = AppDatenSpeicher(datei: datei)
        var daten = speicher.laden()
        XCTAssertEqual(daten.profile.count, 1)
        daten.erscheinung = "hell"
        try speicher.speichern(daten)
        let dateien = try FileManager.default.contentsOfDirectory(atPath: ordner.path)
        XCTAssertFalse(dateien.contains { $0.hasPrefix("appdaten.kaputt-") })
        XCTAssertEqual(speicher.laden().erscheinung, "hell")
    }

    func testGesehenWirdGespeichert() throws {
        var eintrag = GespeichertesProfil(name: "Oma", profil: testProfil(), gewichtung: Gewichtung(profil: testProfil()))
        eintrag.gesehen = ["a", "b"]
        let zurueck = try JSONDecoder().decode(GespeichertesProfil.self, from: JSONEncoder().encode(eintrag))
        XCTAssertEqual(zurueck.gesehen, ["a", "b"])
    }

    func testProfilSchicktBudgetMinImmer() throws {
        let json = String(data: try JSONEncoder().encode(testProfil()), encoding: .utf8)!
        XCTAssertTrue(json.contains("\"budget_min\":null"), json)
        var p = testProfil()
        p.budgetMin = 20
        let zurueck = try JSONDecoder().decode(Profil.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(zurueck.budgetMin, 20)
    }

    func testSammelKartenSchicktPersonenUndLiestFuer() async throws {
        let t = FakeTransport(json: """
        {"karten":[{"fuer":"0","karte":{"id":"a","art":"produkt","titel":"Hochbeet","preis":34.9,
          "bild_url":null,"shop":"S","link":"https://x/a","tags":["garten"]}}],
         "duenn_fuer":["1"],"tag_labels":{"garten":"Garten"}}
        """)
        let api = GeschenkeAPI(basis: URL(string: "https://server.test")!, token: "geheim", transport: t)
        let antwort = try await api.sammelKarten(
            personen: [SammelPerson(id: "0", profil: testProfil(), gesehen: ["x"]),
                       SammelPerson(id: "1", profil: testProfil(), gesehen: [])],
            anzahl: 12)
        XCTAssertEqual(t.anfragen[0].url?.absoluteString, "https://server.test/karten/sammel")
        let body = try JSONSerialization.jsonObject(with: t.anfragen[0].httpBody!) as! [String: Any]
        let personen = body["personen"] as! [[String: Any]]
        XCTAssertEqual(personen[0]["id"] as? String, "0")
        XCTAssertEqual(personen[0]["gesehen"] as? [String], ["x"])
        XCTAssertEqual(body["anzahl"] as? Int, 12)
        XCTAssertEqual(antwort.karten.first?.fuer, "0")
        XCTAssertEqual(antwort.karten.first?.karte.id, "a")
        XCTAssertEqual(antwort.duennFuer, ["1"])
        XCTAssertEqual(antwort.tagLabels["garten"], "Garten")
    }
}
