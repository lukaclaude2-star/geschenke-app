import GeschenkeCore
import SwiftUI

/// Wohin es zum Wischen geht: eine Person (Einzelsuche) oder mehrere (Sammelsuche).
struct WischZiel: Hashable, Identifiable {
    let id = UUID()
    let personen: [WischPerson]

    static func == (a: WischZiel, b: WischZiel) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Besitzt das Stapel-Modell für Wischen aus einem Profil oder der Sammelsuche.
struct WischZielView: View {
    @StateObject private var modell: KartenStapelModell

    init(ziel: WischZiel) {
        _modell = StateObject(wrappedValue: KartenStapelModell(personen: ziel.personen,
                                                              api: AppZustand.apiOhneZustand()))
    }

    var body: some View {
        WischView(modell: modell)
    }
}

struct WischView: View {
    @EnvironmentObject private var zustand: AppZustand
    @ObservedObject var modell: KartenStapelModell
    @State private var versatz: CGSize = .zero
    @State private var zeigeGelernt = false
    @State private var zeigeMerkliste = false
    @State private var gewichteBeimOeffnen: [Gewichtung] = []
    @State private var wischt: String?
    private let schwelle: CGFloat = 100

    var body: some View {
        VStack(spacing: 16) {
            if let hinweis = modell.duennHinweis {
                Text(hinweis)
                    .font(.footnote)
                    .foregroundStyle(Look.akzent)
            }
            ZStack {
                if modell.stapel.isEmpty {
                    leer
                }
                let oben = Array(modell.stapel.prefix(3))
                ForEach(oben.reversed()) { eintrag in
                    let index = oben.firstIndex { $0.id == eintrag.id } ?? 0
                    KartenView(karte: eintrag.karte,
                               labels: modell.personen[eintrag.person].gewichtung.labels,
                               fuer: modell.istSammel ? modell.name(eintrag.person) : nil)
                        .scaleEffect(index == 0 ? 1 : 1 - CGFloat(index) * 0.04)
                        .offset(y: CGFloat(index) * 10)
                        .offset(index == 0 ? versatz : .zero)
                        .rotationEffect(.degrees(index == 0 ? Double(versatz.width / 20) : 0))
                        .overlay(alignment: .top) {
                            if index == 0 { wischHinweis }
                        }
                        .gesture(ziehen(eintrag), including: index == 0 ? .all : .none)
                        .allowsHitTesting(index == 0)
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 28) {
                rundKnopf("arrow.uturn.backward", groesse: 48) { modell.zurueck() }
                    .disabled(!modell.kannZurueck || wischt != nil)
                    .opacity(modell.kannZurueck ? 1 : 0.35)
                if let karte = modell.stapel.first {
                    rundKnopf("xmark") { weg(karte, ja: false) }
                    rundKnopf("heart.fill") { weg(karte, ja: true) }
                }
            }
        }
        .padding()
        .nachtblau()
        .navigationTitle(modell.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    gewichteBeimOeffnen = modell.personen.map(\.gewichtung)
                    zeigeGelernt = true
                } label: { Image(systemName: "slider.horizontal.3") }
                Button { zeigeMerkliste = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.text.square")
                        Text("\(zustand.daten.merkliste.count)").font(.footnote.monospacedDigit())
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeGelernt, onDismiss: {
            modell.sichernJetzt()
            // Nur neu sortieren, wenn sich wirklich etwas geändert hat.
            if modell.personen.map(\.gewichtung) != gewichteBeimOeffnen {
                Task { await modell.neuSortieren() }
            }
        }) {
            GelerntView(modell: modell)
        }
        .sheet(isPresented: $zeigeMerkliste) {
            NavigationStack {
                MerklisteView()
                    .toolbar { Button("Fertig") { zeigeMerkliste = false } }
            }
            .presentationBackground(Look.hintergrund)
        }
        .task {
            modell.verbinde(zustand)
            if modell.stapel.isEmpty { await modell.nachladen() }
        }
    }

    @ViewBuilder private var leer: some View {
        VStack(spacing: 12) {
            if modell.laedt {
                ProgressView().tint(Look.akzent)
                Text(modell.wachtAuf ? "Server wacht auf …" : "Suche passende Geschenke …")
                    .foregroundStyle(Look.leise)
            } else if let fehler = modell.fehler {
                Text(fehler).foregroundStyle(Look.leise).multilineTextAlignment(.center)
                Button("Nochmal") { Task { await modell.nachladen() } }.buttonStyle(RandKnopf())
            } else {
                Image(systemName: "gift").font(.system(size: 54)).foregroundStyle(Look.akzent)
                Text("Mehr passende Geschenke habe ich gerade nicht. Vielleicht schränken Budget oder Ausschlüsse stark ein – ändere das im Profil oder die Gewichtung oben rechts.")
                    .foregroundStyle(Look.leise)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    @ViewBuilder private var wischHinweis: some View {
        if versatz.width > 30 {
            Abzeichen(text: "♥ Merken", gefuellt: true).padding(.top, 20)
                .opacity(Double(min(1, versatz.width / schwelle)))
        } else if versatz.width < -30 {
            Abzeichen(text: "✕ Nein", gefuellt: true).padding(.top, 20)
                .opacity(Double(min(1, -versatz.width / schwelle)))
        }
    }

    private func ziehen(_ karte: StapelKarte) -> some Gesture {
        DragGesture()
            .onChanged { versatz = $0.translation }
            .onEnded { wert in
                if wert.translation.width > schwelle {
                    weg(karte, ja: true)
                } else if wert.translation.width < -schwelle {
                    weg(karte, ja: false)
                } else {
                    withAnimation(.spring) { versatz = .zero }
                }
            }
    }

    private func weg(_ karte: StapelKarte, ja: Bool) {
        guard wischt == nil else { return }
        wischt = karte.id
        withAnimation(.easeOut(duration: 0.2)) {
            versatz = CGSize(width: ja ? 600 : -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if ja { modell.ja(karte) } else { modell.nein(karte) }
            versatz = .zero
            wischt = nil
        }
    }

    private func rundKnopf(_ symbol: String, groesse: CGFloat = 64, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(groesse < 60 ? .title3.bold() : .title2.bold())
                .foregroundStyle(symbol == "heart.fill" ? Look.aufAkzent : Look.akzent)
                .frame(width: groesse, height: groesse)
                .background(symbol == "heart.fill" ? Look.akzent : Look.karte, in: Look.knopfForm)
                .overlay(Look.knopfForm.stroke(Look.akzent, lineWidth: 1.5))
                .contentShape(Look.knopfForm)
        }
    }
}
