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

    func testKaputteDateiGibtLeereDaten() throws {
        let datei = tempDatei()
        try "kaputt".data(using: .utf8)!.write(to: datei)
        XCTAssertTrue(AppDatenSpeicher(datei: datei).laden().profile.isEmpty)
    }
}
