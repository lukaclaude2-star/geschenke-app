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
