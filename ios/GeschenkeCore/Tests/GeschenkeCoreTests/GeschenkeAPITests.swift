import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import GeschenkeCore

final class FakeTransport: Transport {
    var antwort: Result<(Data, Int), Error>
    private(set) var anfragen: [URLRequest] = []

    init(json: String = "{}", status: Int = 200) {
        antwort = .success((json.data(using: .utf8)!, status))
    }

    func senden(_ anfrage: URLRequest) async throws -> (Data, Int) {
        anfragen.append(anfrage)
        return try antwort.get()
    }
}

final class GeschenkeAPITests: XCTestCase {
    private func api(_ transport: FakeTransport) -> GeschenkeAPI {
        GeschenkeAPI(basis: URL(string: "https://server.test")!, token: "geheim", transport: transport)
    }

    private func body(_ anfrage: URLRequest) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: anfrage.httpBody!) as! [String: Any]
    }

    func testSetztBearerUndPfad() async throws {
        let t = FakeTransport(json: #"{"fertig":false,"frage":"Für wen?","platzhalter":"z. B."}"#)
        let antwort = try await api(t).naechsteFrage(laenge: "normal", nachrichten: [])
        XCTAssertEqual(antwort.frage, "Für wen?")
        let anfrage = t.anfragen[0]
        XCTAssertEqual(anfrage.url?.absoluteString, "https://server.test/chat/naechste")
        XCTAssertEqual(anfrage.httpMethod, "POST")
        XCTAssertEqual(anfrage.value(forHTTPHeaderField: "Authorization"), "Bearer geheim")
        XCTAssertEqual(anfrage.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testChatAnfrageSchicktRolleUndText() async throws {
        let t = FakeTransport(json: #"{"fertig":true}"#)
        _ = try await api(t).naechsteFrage(laenge: "schnell",
                                           nachrichten: [ChatNachricht(rolle: "nutzer", text: "Oma")])
        let b = try body(t.anfragen[0])
        XCTAssertEqual(b["laenge"] as? String, "schnell")
        let n = (b["nachrichten"] as! [[String: Any]])[0]
        XCTAssertEqual(n["rolle"] as? String, "nutzer")
        XCTAssertEqual(n["text"] as? String, "Oma")
        XCTAssertNil(n["id"])
    }

    func testKartenAnfrageKodiertSnakeCase() async throws {
        let t = FakeTransport(json: #"{"karten":[],"wird_duenn":false,"tag_labels":{}}"#)
        _ = try await api(t).karten(profil: testProfil(), gesehen: ["a"], anzahl: 10)
        XCTAssertEqual(t.anfragen[0].url?.path, "/karten")
        let b = try body(t.anfragen[0])
        XCTAssertEqual(b["gesehen"] as? [String], ["a"])
        XCTAssertEqual(b["anzahl"] as? Int, 10)
        XCTAssertEqual((b["profil"] as! [String: Any])["budget_max"] as? Double, 50)
    }

    func testProfilPfade() async throws {
        let profilJSON = #"{"zusammenfassung":"Oma","wuensche":[],"ausschluesse":[],"budget_max":null}"#
        let t = FakeTransport(json: profilJSON)
        _ = try await api(t).profilAusGespraech([])
        _ = try await api(t).profilAendern(testProfil(), anweisung: "hat jetzt einen Hund")
        XCTAssertEqual(t.anfragen.map { $0.url?.path }, ["/profil/aus-gespraech", "/profil/aendern"])
        XCTAssertEqual(try body(t.anfragen[1])["anweisung"] as? String, "hat jetzt einen Hund")
    }

    func testTransportFehlerWirdNichtErreichbar() async {
        let t = FakeTransport()
        t.antwort = .failure(URLError(.timedOut))
        await XCTAssertThrowsFehler(.nichtErreichbar) { _ = try await self.api(t).naechsteFrage(laenge: "normal", nachrichten: []) }
    }

    func testStatus503WirdKiUeberlastet() async {
        let t = FakeTransport(json: #"{"fehler":"ki_ueberlastet"}"#, status: 503)
        await XCTAssertThrowsFehler(.kiUeberlastet) { _ = try await self.api(t).profilAusGespraech([]) }
    }

    func testStatus500WirdServerFehler() async {
        let t = FakeTransport(status: 500)
        await XCTAssertThrowsFehler(.server(500)) { _ = try await self.api(t).profilAusGespraech([]) }
    }

    func testUnlesbaresJSONWirdUnlesbar() async {
        let t = FakeTransport(json: "kein json")
        await XCTAssertThrowsFehler(.unlesbar) { _ = try await self.api(t).naechsteFrage(laenge: "normal", nachrichten: []) }
    }

    func testTimeoutIst90Sekunden() async throws {
        let t = FakeTransport(json: #"{"fertig":true}"#)
        _ = try await api(t).naechsteFrage(laenge: "normal", nachrichten: [])
        XCTAssertEqual(t.anfragen[0].timeoutInterval, 90)
    }
}

func XCTAssertThrowsFehler(_ erwartet: APIFehler, _ block: () async throws -> Void,
                           file: StaticString = #filePath, line: UInt = #line) async {
    do {
        try await block()
        XCTFail("kein Fehler geworfen", file: file, line: line)
    } catch let fehler as APIFehler {
        XCTAssertEqual(fehler, erwartet, file: file, line: line)
    } catch {
        XCTFail("falscher Fehler: \(error)", file: file, line: line)
    }
}
