import Foundation
import XCTest
@testable import GeschenkeCore

final class AppDatenTests: XCTestCase {
    private func tempDatei() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    func testSpeicherRundreise() throws {
        let datei = tempDatei()
        let speicher = AppDatenSpeicher(datei: datei)
        var daten = AppDaten()
        let profil = testProfil()
        daten.profile.append(GespeichertesProfil(name: "Oma Gerda", profil: profil,
                                                 gewichtung: Gewichtung(profil: profil)))
        daten.merkliste.append(MerkEintrag(karte: testKarte(), fuer: "Oma Gerda"))
        try speicher.speichern(daten)
        let geladen = speicher.laden()
        XCTAssertEqual(geladen.profile.first?.name, "Oma Gerda")
        XCTAssertEqual(geladen.merkliste.first?.karte.id, "a")
    }

    func testFehlendeDateiGibtLeereDaten() {
        let daten = AppDatenSpeicher(datei: tempDatei()).laden()
        XCTAssertTrue(daten.profile.isEmpty && daten.merkliste.isEmpty)
    }

    func testKaputteDateiWirdVorDemUeberschreibenGesichert() throws {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let datei = ordner.appendingPathComponent("appdaten.json")
        try "alte, unlesbare Daten".data(using: .utf8)!.write(to: datei)
        let speicher = AppDatenSpeicher(datei: datei)
        _ = speicher.laden()
        try speicher.speichern(AppDaten())
        let gesichert = try FileManager.default.contentsOfDirectory(atPath: ordner.path)
            .filter { $0.hasPrefix("appdaten.kaputt-") }
        XCTAssertEqual(gesichert.count, 1)
        let inhalt = try String(contentsOf: ordner.appendingPathComponent(gesichert[0]), encoding: .utf8)
        XCTAssertEqual(inhalt, "alte, unlesbare Daten")
    }

    func testKaputteDateiGibtLeereDaten() throws {
        let datei = tempDatei()
        try "kaputt".data(using: .utf8)!.write(to: datei)
        XCTAssertTrue(AppDatenSpeicher(datei: datei).laden().profile.isEmpty)
    }
}
