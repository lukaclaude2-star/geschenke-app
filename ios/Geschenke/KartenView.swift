import GeschenkeCore
import SwiftUI

struct KartenView: View {
    let karte: Karte
    let labels: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                bild
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipped()
                if karte.istIdee {
                    Abzeichen(text: "Idee").padding(12)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(karte.titel)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(karte.preisText) · \(karte.shop)")
                    .font(.subheadline)
                    .foregroundStyle(Look.leise)
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
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Look.rand))
    }

    @ViewBuilder private var bild: some View {
        if let adresse = karte.bildURL, let url = URL(string: adresse) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let bild): bild.resizable().scaledToFill()
                case .failure: platzhalter
                default: ProgressView().tint(Look.gold).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            platzhalter
        }
    }

    private var platzhalter: some View {
        ZStack {
            RadialGradient(colors: [Look.rand, Look.hintergrund], center: .center, startRadius: 10, endRadius: 220)
            Text(karte.emoji ?? "🎁").font(.system(size: 90))
        }
    }
}
