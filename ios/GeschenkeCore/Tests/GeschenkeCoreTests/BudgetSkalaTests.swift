import XCTest
@testable import GeschenkeCore

final class BudgetSkalaTests: XCTestCase {
    func testBudgetStufen() {
        XCTAssertEqual(BudgetSkala.stufen.first, 5)
        XCTAssertEqual(BudgetSkala.stufen.last, 500)
        XCTAssertTrue(BudgetSkala.stufen.contains(95))
        XCTAssertTrue(BudgetSkala.stufen.contains(100))
        XCTAssertTrue(BudgetSkala.stufen.contains(125))
        XCTAssertFalse(BudgetSkala.stufen.contains(105))
        XCTAssertEqual(BudgetSkala.stufen, BudgetSkala.stufen.sorted())
    }

    func testBudgetGrenzen() {
        XCTAssertTrue(BudgetSkala.grenzen(von: 5, bis: 500) == (nil, nil))
        XCTAssertTrue(BudgetSkala.grenzen(von: 20, bis: 50) == (20, 50))
        XCTAssertTrue(BudgetSkala.grenzen(von: 20, bis: 500) == (20, nil))
        XCTAssertTrue(BudgetSkala.grenzen(von: 5, bis: 50) == (nil, 50))
    }

    func testBudgetText() {
        XCTAssertEqual(BudgetSkala.text(von: 20, bis: 50), "Budget: 20–50 €")
        XCTAssertEqual(BudgetSkala.text(von: 20, bis: nil), "Budget: ab 20 €")
        XCTAssertEqual(BudgetSkala.text(von: nil, bis: 50), "Budget: bis 50 €")
        XCTAssertEqual(BudgetSkala.text(von: nil, bis: nil), "Budget: egal")
    }
}

final class BudgetReglerWerteTests: XCTestCase {
    func testStartwerteMitUntergrenzeAmAnschlag() {
        // KI liest „ab 500 €“ → ohne Klemmen lägen beide Griffe auf der letzten Stufe (Absturz).
        let w = BudgetSkala.startwerte(min: 500, max: nil)
        XCTAssertLessThan(BudgetSkala.index(nahe: w.von), BudgetSkala.index(nahe: w.bis))
        XCTAssertEqual(w.bis, 500)
    }

    func testStartwerteVertauschtOderGleich() {
        let w = BudgetSkala.startwerte(min: 80, max: 30)
        XCTAssertLessThan(BudgetSkala.index(nahe: w.von), BudgetSkala.index(nahe: w.bis))
        let g = BudgetSkala.startwerte(min: 5, max: 5)
        XCTAssertLessThan(BudgetSkala.index(nahe: g.von), BudgetSkala.index(nahe: g.bis))
    }

    func testStartwerteOhneBudget() {
        let w = BudgetSkala.startwerte(min: nil, max: nil)
        XCTAssertEqual(w.von, 5)
        XCTAssertEqual(w.bis, 500)
    }

    func testIndexNahe() {
        XCTAssertEqual(BudgetSkala.stufen[BudgetSkala.index(nahe: 120)], 125)
        XCTAssertEqual(BudgetSkala.index(nahe: 9999), BudgetSkala.stufen.count - 1)
        XCTAssertEqual(BudgetSkala.index(nahe: -3), 0)
    }

    func testGriffeBleibenGetrennt() {
        let letzte = BudgetSkala.stufen.count - 1
        XCTAssertEqual(BudgetSkala.vonIndex(gezogen: letzte, bisIndex: letzte), letzte - 1)
        XCTAssertEqual(BudgetSkala.bisIndex(gezogen: 0, vonIndex: 0), 1)
        XCTAssertEqual(BudgetSkala.bisIndex(gezogen: 0, vonIndex: letzte), letzte)
        XCTAssertEqual(BudgetSkala.vonIndex(gezogen: 3, bisIndex: 0), 0)
    }
}
