import GeschenkeCore
import SwiftUI

struct KartenView: View {
    let karte: Karte
    let labels: [String: String]
    /// In der Sammelsuche: für wen die Karte gedacht ist.
    var fuer: String?

    var body: some View {
        let ecken: CGFloat = Look.stil == .deco ? 2 : (Look.stil == .pinnwand ? 4 : 20)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                KartenBild(karte: karte, ecken: Look.stil == .pinnwand ? 2 : 0)
                    .padding(Look.stil == .pinnwand ? 10 : 0)
                if karte.istIdee {
                    Abzeichen(text: "Idee").padding(Look.stil == .pinnwand ? 20 : 12)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                if let fuer {
                    if Look.stil == .pinnwand {
                        Text("→ für \(fuer)").font(.custom("Noteworthy-Bold", size: 16, relativeTo: .subheadline))
                            .foregroundStyle(Look.akzent)
                    } else {
                        Abzeichen(text: "für \(fuer)", gefuellt: true)
                    }
                }
                Text(karte.titel)
                    .font(Look.titelSchrift)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(karte.preisText).font(.subheadline.bold()).foregroundStyle(Look.preis)
                    Text("· \(karte.shop)").font(.subheadline).foregroundStyle(Look.leise)
                }
                HStack(spacing: 6) {
                    ForEach(karte.tags.prefix(3), id: \.self) { tag in
                        Abzeichen(text: labels[tag] ?? tag)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Look.karte)
        .clipShape(RoundedRectangle(cornerRadius: ecken))
        .overlay { rahmen(ecken) }
        .overlay(alignment: .top) {
            if Look.stil == .pinnwand {
                // Klebestreifen
                Rectangle().fill(Color.white.opacity(0.55))
                    .frame(width: 90, height: 24)
                    .rotationEffect(.degrees(-4))
                    .offset(y: -12)
            }
        }
        .rotationEffect(.degrees(Look.stil == .pinnwand ? 2 : 0))
        .shadow(color: .black.opacity(Look.stil == .pinnwand ? 0.35 : 0), radius: 8, y: 5)
    }

    @ViewBuilder private func rahmen(_ ecken: CGFloat) -> some View {
        switch Look.stil {
        case .deco:
            ZStack {
                RoundedRectangle(cornerRadius: ecken).stroke(Look.akzent, lineWidth: 1)
                RoundedRectangle(cornerRadius: ecken).inset(by: 5).stroke(Look.akzent.opacity(0.7), lineWidth: 1)
            }
        case .pinnwand:
            EmptyView()
        case .normal:
            RoundedRectangle(cornerRadius: ecken).stroke(Look.rand)
        }
    }
}
