import GeschenkeCore
import SwiftUI

/// Wohin es nach dem Gespräch oder aus einem Profil zum Wischen geht.
struct WischZiel: Hashable, Identifiable {
    let id = UUID()
    let name: String?
    let profil: Profil
    let profilID: UUID?
    let gewichtung: Gewichtung

    static func == (a: WischZiel, b: WischZiel) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ChatView: View {
    @EnvironmentObject private var zustand: AppZustand
    @StateObject private var modell: ChatModell
    @State private var eingabe = ""
    @State private var zeigeSpeichern = false
    @State private var ziel: WischZiel?
    @FocusState private var fokus: Bool

    init(laenge: String) {
        _modell = StateObject(wrappedValue: ChatModell(laenge: laenge, api: AppZustand.apiOhneZustand()))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { leser in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(modell.nachrichten) { nachricht in
                            Blase(nachricht: nachricht).id(nachricht.id)
                        }
                        if modell.denkt {
                            HStack(spacing: 8) {
                                ProgressView().tint(Look.gold)
                                Text(modell.wachtAuf ? "Server wacht auf …" : "…")
                                    .foregroundStyle(Look.leise)
                            }
                            .id("denkt")
                        }
                        if let fehler = modell.fehler {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(fehler).foregroundStyle(Look.leise)
                                Button("Nochmal") { Task { await modell.nochmal() } }
                                    .buttonStyle(RandKnopf())
                            }
                            .id("fehler")
                        }
                    }
                    .padding()
                }
                .onChange(of: modell.nachrichten.count) {
                    if let letzte = modell.nachrichten.last?.id {
                        withAnimation { leser.scrollTo(letzte, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("", text: $eingabe, prompt: Text(modell.platzhalter).foregroundStyle(Look.leise),
                          axis: .vertical)
                    .lineLimit(1...4)
                    .focused($fokus)
                    .padding(10)
                    .background(Look.karte)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Look.rand))
                Button {
                    let text = eingabe
                    eingabe = ""
                    Task { await modell.senden(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }
                .disabled(eingabe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !modell.kannSenden)
            }
            .padding()
        }
        .nachtblau()
        .navigationTitle("Erzähl mal")
        .navigationBarTitleDisplayMode(.inline)
        .task { await modell.start() }
        .onChange(of: modell.profil) {
            if modell.profil != nil { zeigeSpeichern = true }
        }
        .sheet(isPresented: $zeigeSpeichern) {
            if let profil = modell.profil {
                ProfilSpeichernView(profil: profil) { name in
                    zeigeSpeichern = false
                    let gewichtung = Gewichtung(profil: profil)
                    var id: UUID?
                    if let name { id = zustand.speichereProfil(name: name, profil: profil, gewichtung: gewichtung) }
                    ziel = WischZiel(name: name, profil: profil, profilID: id, gewichtung: gewichtung)
                }
                .interactiveDismissDisabled()
            }
        }
        .navigationDestination(item: $ziel) { ziel in
            WischView(ziel: ziel)
        }
    }
}

extension AppZustand {
    /// Der Chat braucht nur die Server-Verbindung, nicht den gespeicherten Zustand.
    nonisolated static func apiOhneZustand() -> GeschenkeAPI {
        GeschenkeAPI(basis: Konfiguration.serverURL, token: Konfiguration.token, transport: URLSessionTransport())
    }
}

struct Blase: View {
    let nachricht: ChatNachricht

    var body: some View {
        let vonApp = nachricht.rolle == "app"
        HStack {
            if !vonApp { Spacer(minLength: 40) }
            Text(nachricht.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(vonApp ? Look.text : Look.hintergrund)
                .background(vonApp ? Look.karte : Look.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if vonApp { Spacer(minLength: 40) }
        }
    }
}

struct ProfilSpeichernView: View {
    let profil: Profil
    let fertig: (String?) -> Void
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Als Profil speichern?").font(.title3.bold())
            Text(profil.zusammenfassung).foregroundStyle(Look.leise)
            TextField("", text: $name, prompt: Text("z. B. Oma Gerda").foregroundStyle(Look.leise))
                .padding(10)
                .background(Look.karte)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button("Speichern und los") {
                fertig(name.trimmingCharacters(in: .whitespaces))
            }
            .buttonStyle(GoldKnopf())
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Nicht speichern, einfach los") { fertig(nil) }
                .buttonStyle(RandKnopf())
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationBackground(Look.hintergrund)
    }
}
