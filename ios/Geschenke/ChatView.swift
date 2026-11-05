import GeschenkeCore
import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var zustand: AppZustand
    @StateObject private var modell: ChatModell
    @State private var eingabe = ""
    @State private var zeigeSpeichern = false
    /// Der Stapel gehört zur Suche, nicht zur Wisch-Ansicht: versehentliches Zurück verliert nichts.
    @State private var stapel: KartenStapelModell?
    @State private var zeigeWischen = false
    @State private var budgetVon = BudgetSkala.minimum
    @State private var budgetBis: Double = 50
    @FocusState private var fokus: Bool

    init(laenge: String) {
        _modell = StateObject(wrappedValue: ChatModell(laenge: laenge, api: AppZustand.apiOhneZustand()))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { leser in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        // EU AI Act Art. 50: Wer mit einer KI schreibt, muss das wissen.
                        Text("Du schreibst mit einer KI. Sie kann sich irren.")
                            .font(.zuhause(.footnote)).foregroundStyle(Look.leise)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                        ForEach(modell.nachrichten) { nachricht in
                            Blase(nachricht: nachricht).id(nachricht.id)
                        }
                        if modell.denkt {
                            HStack(spacing: 8) {
                                ProgressView().tint(Look.akzentText)
                                Text(modell.wachtAuf ? wachtAufText : "…")
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

            unten
        }
        .zuhauseHintergrund()
        .navigationTitle("Erzähl mal")
        .navigationBarTitleDisplayMode(.inline)
        .task { await modell.start() }
        .onChange(of: modell.profil) {
            if modell.profil != nil, stapel == nil { zeigeSpeichern = true }
        }
        .sheet(isPresented: $zeigeSpeichern, onDismiss: {
            // Erst nach dem Schließen des Blatts weiter – sonst verschluckt SwiftUI den Wechsel.
            if stapel != nil { zeigeWischen = true }
        }) {
            if let profil = modell.profil {
                ProfilSpeichernView(profil: profil) { name in
                    let gewichtung = Gewichtung(profil: profil)
                    var id: UUID?
                    if let name { id = zustand.speichereProfil(name: name, profil: profil, gewichtung: gewichtung) }
                    stapel = KartenStapelModell(
                        personen: [WischPerson(name: name, profil: profil, profilID: id, gewichtung: gewichtung)],
                        api: AppZustand.apiOhneZustand())
                    zeigeSpeichern = false
                }
                .interactiveDismissDisabled()
            }
        }
        .navigationDestination(isPresented: $zeigeWischen) {
            if let stapel { ZuhauseWischView(modell: stapel) }
        }
    }

    @ViewBuilder private var unten: some View {
        if stapel != nil {
            VStack(alignment: .leading, spacing: 12) {
                if let profil = modell.profil { ErkannteStichwoerter(profil: profil) }
                Button("Weiter wischen") { zeigeWischen = true }
                    .buttonStyle(GoldKnopf())
            }
            .padding()
        } else if modell.budgetOffen {
            VStack(spacing: 14) {
                BudgetRegler(von: $budgetVon, bis: $budgetBis)
                HStack(spacing: 10) {
                    Button("Egal") { Task { await modell.budgetGewaehlt(von: nil, bis: nil) } }
                        .buttonStyle(RandKnopf())
                    Button("Passt") {
                        let grenzen = BudgetSkala.grenzen(von: budgetVon, bis: budgetBis)
                        Task { await modell.budgetGewaehlt(von: grenzen.min, bis: grenzen.max) }
                    }
                    .buttonStyle(GoldKnopf())
                }
            }
            .padding()
            .background(Look.karte)
        } else {
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
    }
}

extension AppZustand {
    /// Chat und Stapel brauchen nur die Server-Verbindung, nicht den gespeicherten Zustand.
    nonisolated static func apiOhneZustand() -> GeschenkeAPI {
        GeschenkeAPI(basis: Konfiguration.serverURL, token: Konfiguration.token, transport: URLSessionTransport())
    }
}

struct Blase: View {
    let nachricht: ChatNachricht

    var body: some View {
        let vonApp = nachricht.rolle == "app"
        let ecken: CGFloat = 18
        HStack {
            if !vonApp { Spacer(minLength: 40) }
            Text(nachricht.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(vonApp ? Look.text : Look.aufAkzent)
                .background(vonApp ? Look.karte : Look.akzent)
                .clipShape(RoundedRectangle(cornerRadius: ecken))
                .overlay {
                    // Hell: feine Kante wie bei den Karten (DESIGN.md 5)
                    if vonApp && Look.palette.hell {
                        RoundedRectangle(cornerRadius: ecken).stroke(Look.rand, lineWidth: 1)
                    }
                }
            if vonApp { Spacer(minLength: 40) }
        }
    }
}

struct ProfilSpeichernView: View {
    let profil: Profil
    let fertig: (String?) -> Void
    @State private var name = ""
    /// Doppeltipp würde sonst zwei Profile anlegen.
    @State private var speichert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Als Profil speichern?").font(.titel(.title3))
            Text(profil.zusammenfassung).foregroundStyle(Look.leise)
            ErkannteStichwoerter(profil: profil)
            TextField("", text: $name, prompt: Text("z. B. Oma Gerda").foregroundStyle(Look.leise))
                .padding(10)
                .background(Look.karte)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button("Speichern und los") {
                guard !speichert else { return }
                speichert = true
                fertig(name.trimmingCharacters(in: .whitespaces))
            }
            .buttonStyle(GoldKnopf())
            .disabled(speichert || name.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Nicht speichern, einfach los") {
                guard !speichert else { return }
                speichert = true
                fertig(nil)
            }
            .buttonStyle(RandKnopf())
            .disabled(speichert)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationBackground(Look.hintergrund)
    }
}

/// Nach dem Chat sichtbar, welche Stichwörter die App verstanden hat – fehlt eins, fällt es sofort auf.
struct ErkannteStichwoerter: View {
    let profil: Profil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Erkannte Stichwörter").font(.zuhause(.subheadline, .halbfett))
            if profil.wuensche.isEmpty {
                Text("Noch keine. Erzähl ruhig mehr über Hobbys und Interessen.")
                    .font(.zuhause(.footnote)).foregroundStyle(Look.leise)
            } else {
                FlussLayout(abstand: 6) {
                    ForEach(profil.wuensche, id: \.tag) { Abzeichen(text: ohneEmoji($0.label)) }
                }
            }
            if !profil.ausschluesse.isEmpty {
                Text("Nie: " + profil.ausschluesse.map { ohneEmoji($0.label) }.joined(separator: ", "))
                    .font(.zuhause(.footnote)).foregroundStyle(Look.leise)
            }
        }
    }
}
