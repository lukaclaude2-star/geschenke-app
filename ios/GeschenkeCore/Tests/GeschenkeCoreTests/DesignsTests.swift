import XCTest
@testable import GeschenkeCore

final class DesignsTests: XCTestCase {
    func testAchtDesignsStandardZuerst() {
        XCTAssertEqual(Designs.alle.map(\.id),
                       ["nachtblau", "wald", "bordeaux", "polarlicht", "graphit", "mint", "deco", "pinnwand"])
        XCTAssertEqual(Designs.standard, "nachtblau")
    }

    func testUnbekanntWirdStandard() {
        XCTAssertEqual(Designs.palette("gibtsnicht").id, "nachtblau")
        XCTAssertEqual(Designs.palette("deco").stil, .deco)
        XCTAssertEqual(Designs.palette("pinnwand").stil, .pinnwand)
        XCTAssertTrue(Designs.palette("mint").hell)
        XCTAssertFalse(Designs.palette("wald").hell)
    }

    func testKontrastBekannt() {
        XCTAssertEqual(kontrast(0x000000, 0xFFFFFF), 21, accuracy: 0.01)
        XCTAssertEqual(kontrast(0xFFFFFF, 0x000000), 21, accuracy: 0.01)
        XCTAssertEqual(kontrast(0x777777, 0x777777), 1, accuracy: 0.01)
    }

    func testAllesLesbar() {
        for p in Designs.alle {
            XCTAssertGreaterThanOrEqual(kontrast(p.text, p.karte), 4.5, "\(p.id) Text/Karte")
            XCTAssertGreaterThanOrEqual(kontrast(p.text, p.hintergrund), 4.5, "\(p.id) Text/Hintergrund")
            XCTAssertGreaterThanOrEqual(kontrast(p.aufAkzent, p.akzent), 4.5, "\(p.id) Knopf")
            XCTAssertGreaterThanOrEqual(kontrast(p.preis, p.karte), 4.5, "\(p.id) Preis")
        }
    }
}
