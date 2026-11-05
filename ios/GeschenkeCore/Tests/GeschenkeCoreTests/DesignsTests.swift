import XCTest
@testable import GeschenkeCore

final class DesignsTests: XCTestCase {
    func testKontrastBekannt() {
        XCTAssertEqual(kontrast(0x000000, 0xFFFFFF), 21, accuracy: 0.01)
        XCTAssertEqual(kontrast(0xFFFFFF, 0x000000), 21, accuracy: 0.01)
        XCTAssertEqual(kontrast(0x777777, 0x777777), 1, accuracy: 0.01)
    }

    func testAllesLesbar() {
        for p in [Designs.zuhauseAbend, Designs.zuhauseHell] {
            XCTAssertGreaterThanOrEqual(kontrast(p.text, p.karte), 4.5, "\(p.hell) Text/Karte")
            XCTAssertGreaterThanOrEqual(kontrast(p.text, p.hintergrund), 4.5, "\(p.hell) Text/Hintergrund")
            XCTAssertGreaterThanOrEqual(kontrast(p.aufAkzent, p.akzent), 4.5, "\(p.hell) Knopf")
            XCTAssertGreaterThanOrEqual(kontrast(p.preis, p.karte), 4.5, "\(p.hell) Preis")
            XCTAssertGreaterThanOrEqual(kontrast(p.preis, p.hintergrund), 4.5, "\(p.hell) Preis/Hintergrund")
        }
    }

    func testFarbweltenHellUndDunkel() {
        XCTAssertFalse(Designs.zuhauseAbend.hell)
        XCTAssertTrue(Designs.zuhauseHell.hell)
        XCTAssertEqual(Designs.zuhauseAbend.hintergrund, 0x23160C)
        XCTAssertEqual(Designs.zuhauseHell.hintergrund, 0xEFE6D6)
    }

    func testFarbweltFolgtErscheinung() {
        let p: (Erscheinung, Bool) -> Palette = { Designs.palette(erscheinung: $0, systemDunkel: $1) }
        XCTAssertFalse(p(.automatisch, true).hell)
        XCTAssertTrue(p(.automatisch, false).hell)
        XCTAssertTrue(p(.hell, true).hell)
        XCTAssertFalse(p(.abendlicht, false).hell)
    }

    func testErzwingtHell() {
        XCTAssertNil(Designs.erzwingtHell(.automatisch))
        XCTAssertEqual(Designs.erzwingtHell(.hell), true)
        XCTAssertEqual(Designs.erzwingtHell(.abendlicht), false)
    }
}
