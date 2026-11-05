import XCTest
@testable import GeschenkeCore

/// Stichwort-Labels vom Server tragen ein Emoji vorn („🍳 Kochen“); die App zeigt keine
/// Emojis (DESIGN.md 4).
final class TexteTests: XCTestCase {
    func testEmojiVornWirdEntfernt() {
        XCTAssertEqual(ohneEmoji("🍳 Kochen"), "Kochen")
        XCTAssertEqual(ohneEmoji("🍷 Wein"), "Wein")
    }

    func testEmojiMitVariantenzeichenUndZwj() {
        XCTAssertEqual(ohneEmoji("❤️ Liebe"), "Liebe")
        XCTAssertEqual(ohneEmoji("👨‍🍳 Profikoch"), "Profikoch")
    }

    func testTextOhneEmojiBleibtGleich() {
        XCTAssertEqual(ohneEmoji("Küche & Kochen"), "Küche & Kochen")
        XCTAssertEqual(ohneEmoji("Spiele 2 Personen #1"), "Spiele 2 Personen #1")
        XCTAssertEqual(ohneEmoji(""), "")
    }
}
