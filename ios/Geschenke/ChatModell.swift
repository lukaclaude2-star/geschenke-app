import Foundation
import GeschenkeCore

/// Führt das Gespräch: holt die nächste Frage, fragt nach der ersten Antwort das Budget per
/// Regler ab (Grundbaustein 7, Ausnahme) und baut am Ende das Profil.
@MainActor
final class ChatModell: ObservableObject {
    static let budgetFrage = "Wie viel möchtest du ausgeben?"
    static let schlussfrage = "Gibt es sonst noch etwas, das ich wissen sollte?"

    @Published private(set) var nachrichten: [ChatNachricht] = []
    @Published private(set) var platzhalter = ""
    @Published private(set) var denkt = false
    @Published private(set) var wachtAuf = false
    @Published private(set) var fehler: String?
    @Published private(set) var profil: Profil?
    @Published private(set) var budgetOffen = false

    let laenge: String
    private let api: GeschenkeAPI
    private var letzteAktion: (() async -> Void)?
    private var budget: (min: Double?, max: Double?)?

    init(laenge: String, api: GeschenkeAPI) {
        self.laenge = laenge
        self.api = api
    }

    var kannSenden: Bool {
        !denkt && !budgetOffen && fehler == nil && profil == nil && nachrichten.last?.rolle == "app"
    }

    func start() async {
        guard nachrichten.isEmpty, !denkt else { return }
        await naechsteFrage()
    }

    func senden(_ text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, kannSenden else { return }
        nachrichten.append(ChatNachricht(rolle: "nutzer", text: text))
        if budget == nil, nachrichten.filter({ $0.rolle == "nutzer" }).count == 1 {
            nachrichten.append(ChatNachricht(rolle: "app", text: Self.budgetFrage))
            platzhalter = ""
            budgetOffen = true
            return
        }
        await naechsteFrage()
    }

    /// Vom Regler: nil = keine Grenze auf dieser Seite.
    func budgetGewaehlt(von: Double?, bis: Double?) async {
        guard budgetOffen else { return }
        budgetOffen = false
        budget = (von, bis)
        nachrichten.append(ChatNachricht(rolle: "nutzer", text: BudgetSkala.text(von: von, bis: bis)))
        await naechsteFrage()
    }

    func nochmal() async {
        fehler = nil
        await letzteAktion?()
    }

    /// Die Budget-Frage stellt die App, nicht die KI – der Server soll sie nicht als KI-Frage zählen.
    private var fuerServer: [ChatNachricht] {
        nachrichten.filter { !($0.rolle == "app" && $0.text == Self.budgetFrage) }
    }

    private func naechsteFrage() async {
        letzteAktion = { [weak self] in await self?.naechsteFrage() }
        await mitWarten {
            let antwort = try await self.api.naechsteFrage(laenge: self.laenge, nachrichten: self.fuerServer)
            if antwort.fertig {
                await self.profilBauen()
            } else if let frage = antwort.frage, !frage.trimmingCharacters(in: .whitespaces).isEmpty {
                self.nachrichten.append(ChatNachricht(rolle: "app", text: frage))
                self.platzhalter = antwort.platzhalter ?? ""
            } else {
                // Server sagt „nicht fertig“, liefert aber keine Frage: nicht hängen bleiben.
                self.nachrichten.append(ChatNachricht(rolle: "app", text: Self.schlussfrage))
                self.platzhalter = ""
            }
        }
    }

    private func profilBauen() async {
        letzteAktion = { [weak self] in await self?.profilBauen() }
        await mitWarten {
            var neu = try await self.api.profilAusGespraech(self.fuerServer)
            // Der Regler gewinnt gegen das, was die KI aus dem Text liest.
            if let budget = self.budget {
                neu.budgetMin = budget.min
                neu.budgetMax = budget.max
            }
            self.profil = neu
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
