import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Schickt eine Anfrage und liefert Body + HTTP-Status. Die App nutzt URLSession,
/// die Tests einen Fake – so bleibt der Kern ohne Netzwerk testbar.
public protocol Transport {
    func senden(_ anfrage: URLRequest) async throws -> (Data, Int)
}

public enum APIFehler: Error, Equatable {
    case nichtErreichbar
    case kiUeberlastet
    case server(Int)
    case unlesbar
    /// Ohne gültige KI-Zustimmung verlässt keine Anfrage das Handy.
    case keineEinwilligung
}

public struct GeschenkeAPI {
    /// Render Free schläft nach 15 Minuten; das Aufwachen dauert bis zu einer Minute.
    public static let zeitlimit: TimeInterval = 90

    private let basis: URL
    private let token: String
    private let transport: Transport
    private let darfSenden: @Sendable () -> Bool

    /// `darfSenden` wird vor jeder Anfrage gefragt: die eine Stelle, an der die KI-Zustimmung gilt.
    public init(basis: URL, token: String, transport: Transport, darfSenden: @escaping @Sendable () -> Bool = { true }) {
        self.basis = basis
        self.token = token
        self.transport = transport
        self.darfSenden = darfSenden
    }

    public func naechsteFrage(laenge: String, nachrichten: [ChatNachricht]) async throws -> ChatAntwort {
        try await post("chat/naechste", ChatAnfrage(laenge: laenge, nachrichten: nachrichten))
    }

    public func profilAusGespraech(_ nachrichten: [ChatNachricht]) async throws -> Profil {
        try await post("profil/aus-gespraech", ProfilAusGespraechAnfrage(nachrichten: nachrichten))
    }

    public func profilAendern(_ profil: Profil, anweisung: String) async throws -> Profil {
        try await post("profil/aendern", ProfilAendernAnfrage(profil: profil, anweisung: anweisung))
    }

    public func karten(profil: Profil, gesehen: [String], anzahl: Int) async throws -> KartenAntwort {
        try await post("karten", KartenAnfrage(profil: profil, gesehen: gesehen, anzahl: anzahl))
    }

    public func sammelKarten(personen: [SammelPerson], anzahl: Int) async throws -> KartenSammelAntwort {
        try await post("karten/sammel", KartenSammelAnfrage(personen: personen, anzahl: anzahl))
    }

    private func post<Anfrage: Encodable, Antwort: Decodable>(_ pfad: String, _ inhalt: Anfrage) async throws -> Antwort {
        guard darfSenden() else { throw APIFehler.keineEinwilligung }
        var anfrage = URLRequest(url: basis.appendingPathComponent(pfad), timeoutInterval: Self.zeitlimit)
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        anfrage.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        anfrage.httpBody = try JSONEncoder().encode(inhalt)

        let daten: Data
        let status: Int
        do {
            (daten, status) = try await transport.senden(anfrage)
        } catch {
            throw APIFehler.nichtErreichbar
        }
        if status == 503 { throw APIFehler.kiUeberlastet }
        guard (200..<300).contains(status) else { throw APIFehler.server(status) }
        do {
            return try JSONDecoder().decode(Antwort.self, from: daten)
        } catch {
            throw APIFehler.unlesbar
        }
    }
}
