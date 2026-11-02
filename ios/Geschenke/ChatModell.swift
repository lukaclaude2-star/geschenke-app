import Foundation
import GeschenkeCore

/// Führt das Gespräch: holt die nächste Frage, merkt sich den Platzhalter und baut am Ende das Profil.
@MainActor
final class ChatModell: ObservableObject {
    @Published private(set) var nachrichten: [ChatNachricht] = []
    @Published private(set) var platzhalter = ""
    @Published private(set) var denkt = false
    @Published private(set) var wachtAuf = false
    @Published private(set) var fehler: String?
    @Published private(set) var profil: Profil?

    let laenge: String
    private let api: GeschenkeAPI
    private var letzteAktion: (() async -> Void)?

    init(laenge: String, api: GeschenkeAPI) {
        self.laenge = laenge
        self.api = api
    }

    var kannSenden: Bool { !denkt && fehler == nil && profil == nil && nachrichten.last?.rolle == "app" }

    func start() async {
        guard nachrichten.isEmpty, !denkt else { return }
        await naechsteFrage()
    }

    func senden(_ text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, kannSenden else { return }
        nachrichten.append(ChatNachricht(rolle: "nutzer", text: text))
        await naechsteFrage()
    }

    func nochmal() async {
        fehler = nil
        await letzteAktion?()
    }

    private func naechsteFrage() async {
        letzteAktion = { [weak self] in await self?.naechsteFrage() }
        await mitWarten {
            let antwort = try await self.api.naechsteFrage(laenge: self.laenge, nachrichten: self.nachrichten)
            if antwort.fertig {
                await self.profilBauen()
            } else if let frage = antwort.frage {
                self.nachrichten.append(ChatNachricht(rolle: "app", text: frage))
                self.platzhalter = antwort.platzhalter ?? ""
            }
        }
    }

    private func profilBauen() async {
        letzteAktion = { [weak self] in await self?.profilBauen() }
        await mitWarten {
            self.profil = try await self.api.profilAusGespraech(self.nachrichten)
        }
    }

    /// Zeigt nach 5 Sekunden „Server wacht auf …“ – Render Free braucht aus dem Schlaf bis zu einer Minute.
    private func mitWarten(_ arbeit: @escaping () async throws -> Void) async {
        denkt = true
        wachtAuf = false
        let hinweis = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { self?.wachtAuf = true }
        }
        do {
            try await arbeit()
        } catch {
            fehler = fehlerText(error)
        }
        hinweis.cancel()
        denkt = false
        wachtAuf = false
    }
}
