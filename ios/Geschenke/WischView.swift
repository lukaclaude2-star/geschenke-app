import GeschenkeCore
import SwiftUI

struct WischView: View {
    @EnvironmentObject private var zustand: AppZustand
    @StateObject private var modell: KartenStapelModell
    @State private var versatz: CGSize = .zero
    @State private var zeigeGelernt = false
    private let schwelle: CGFloat = 100

    init(ziel: WischZiel) {
        _modell = StateObject(wrappedValue: KartenStapelModell(ziel: ziel, api: AppZustand.apiOhneZustand()))
    }

    var body: some View {
        VStack(spacing: 16) {
            if modell.wirdDuenn {
                Text(modell.duennHinweis)
                    .font(.footnote)
                    .foregroundStyle(Look.gold)
            }
            ZStack {
                if modell.stapel.isEmpty {
                    leer
                }
                let oben = Array(modell.stapel.prefix(3))
                ForEach(oben.reversed()) { karte in
                    let index = oben.firstIndex { $0.id == karte.id } ?? 0
                    KartenView(karte: karte, labels: modell.gewichtung.labels)
                        .scaleEffect(index == 0 ? 1 : 1 - CGFloat(index) * 0.04)
                        .offset(y: CGFloat(index) * 10)
                        .offset(index == 0 ? versatz : .zero)
                        .rotationEffect(.degrees(index == 0 ? Double(versatz.width / 20) : 0))
                        .overlay(alignment: .top) {
                            if index == 0 { wischHinweis }
                        }
                        .gesture(ziehen(karte), including: index == 0 ? .all : .none)
                        .allowsHitTesting(index == 0)
                }
            }
            .frame(maxHeight: .infinity)

            if let karte = modell.stapel.first {
                HStack(spacing: 40) {
                    rundKnopf("xmark") { weg(karte, ja: false) }
                    rundKnopf("heart.fill") { weg(karte, ja: true) }
                }
            }
        }
        .padding()
        .nachtblau()
        .navigationTitle(modell.name ?? "Vorschläge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { zeigeGelernt = true } label: { Image(systemName: "slider.horizontal.3") }
            }
        }
        .sheet(isPresented: $zeigeGelernt, onDismiss: { Task { await modell.neuSortieren() } }) {
            GelerntView(modell: modell)
        }
        .task {
            modell.verbinde(zustand)
            if modell.stapel.isEmpty { await modell.nachladen() }
        }
    }

    @ViewBuilder private var leer: some View {
        VStack(spacing: 12) {
            if modell.laedt {
                ProgressView().tint(Look.gold)
                Text("Suche passende Geschenke …").foregroundStyle(Look.leise)
            } else if let fehler = modell.fehler {
                Text(fehler).foregroundStyle(Look.leise).multilineTextAlignment(.center)
                Button("Nochmal") { Task { await modell.nachladen() } }.buttonStyle(RandKnopf())
            } else {
                Text("🎁").font(.system(size: 60))
                Text("Mehr passende Geschenke habe ich gerade nicht. Ändere die Gewichtung oben rechts oder schau in deine Merkliste.")
                    .foregroundStyle(Look.leise)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    @ViewBuilder private var wischHinweis: some View {
        if versatz.width > 30 {
            Abzeichen(text: "♥ Merken").padding(.top, 20).opacity(Double(min(1, versatz.width / schwelle)))
        } else if versatz.width < -30 {
            Abzeichen(text: "✕ Nein").padding(.top, 20).opacity(Double(min(1, -versatz.width / schwelle)))
        }
    }

    private func ziehen(_ karte: Karte) -> some Gesture {
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

    private func weg(_ karte: Karte, ja: Bool) {
        withAnimation(.easeOut(duration: 0.2)) {
            versatz = CGSize(width: ja ? 600 : -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if ja { modell.ja(karte) } else { modell.nein(karte) }
            versatz = .zero
        }
    }

    private func rundKnopf(_ symbol: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundStyle(Look.gold)
                .frame(width: 64, height: 64)
                .background(Look.karte)
                .overlay(Circle().stroke(Look.gold, lineWidth: 1.5))
                .clipShape(Circle())
        }
    }
}
