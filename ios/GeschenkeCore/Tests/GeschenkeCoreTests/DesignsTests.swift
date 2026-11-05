import XCTest
@testable import GeschenkeCore

final class DesignsTests: XCTestCase {
    func testNurNochZuhause() {
        XCTAssertEqual(Designs.alle.map(\.id), ["zuhause"])
        XCTAssertEqual(Designs.standard, "zuhause")
        XCTAssertEqual(Designs.zuhauseID, "zuhause")
        XCTAssertEqual(Designs.palette("zuhause"), Designs.zuhauseAbend)
    }

    func testAlteDesignsWerdenZuhause() {
        for alt in ["gibtsnicht", "nachtblau", "wald", "deco", "pinnwand", "mint"] {
            XCTAssertEqual(Designs.palette(alt), Designs.zuhauseAbend, alt)
            XCTAssertTrue(Designs.palette(alt, erscheinung: .hell, systemDunkel: true).hell, alt)
            XCTAssertNil(Designs.erzwingtHell(alt, erscheinung: .automatisch), alt)
        }
    }

    func testKontrastBekannt() {
        XCTAssertEqual(kontrast(0x000000, 0xFFFFFF), 21, accuracy: 0.01)
        XCTAssertEqual(kontrast(0xFFFFFF, 0x000000), 21, accuracy: 0.01)
        XCTAssertEqual(kontrast(0x777777, 0x777777), 1, accuracy: 0.01)
    }

    func testAllesLesbar() {
        for p in Designs.alle + [Designs.zuhauseHell] {
            XCTAssertGreaterThanOrEqual(kontrast(p.text, p.karte), 4.5, "\(p.id) Text/Karte")
            XCTAssertGreaterThanOrEqual(kontrast(p.text, p.hintergrund), 4.5, "\(p.id) Text/Hintergrund")
            XCTAssertGreaterThanOrEqual(kontrast(p.aufAkzent, p.akzent), 4.5, "\(p.id) Knopf")
            XCTAssertGreaterThanOrEqual(kontrast(p.preis, p.karte), 4.5, "\(p.id) Preis")
        }
    }

    func testZuhausePaletten() {
        for p in [Designs.zuhauseAbend, Designs.zuhauseHell] {
            XCTAssertEqual(p.id, "zuhause")
            XCTAssertEqual(p.name, "Zuhause")
            XCTAssertEqual(p.stil, .zuhause)
        }
        XCTAssertFalse(Designs.zuhauseAbend.hell)
        XCTAssertTrue(Designs.zuhauseHell.hell)
    }

    func testZuhauseFolgtErscheinung() {
        let p: (Erscheinung, Bool) -> Palette = { Designs.palette("zuhause", erscheinung: $0, systemDunkel: $1) }
        XCTAssertFalse(p(.automatisch, true).hell)
        XCTAssertTrue(p(.automatisch, false).hell)
        XCTAssertTrue(p(.hell, true).hell)
        XCTAssertFalse(p(.abendlicht, false).hell)
        XCTAssertEqual(p(.hell, true).stil, .zuhause)
        XCTAssertEqual(p(.abendlicht, false).hintergrund, 0x23160C)
        XCTAssertEqual(p(.hell, false).hintergrund, 0xEFE6D6)
    }

    func testErzwingtHell() {
        XCTAssertNil(Designs.erzwingtHell("zuhause", erscheinung: .automatisch))
        XCTAssertEqual(Designs.erzwingtHell("zuhause", erscheinung: .hell), true)
        XCTAssertEqual(Designs.erzwingtHell("zuhause", erscheinung: .abendlicht), false)
    }
}
