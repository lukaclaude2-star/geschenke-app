import GeschenkeCore
import SwiftUI

/// Jedes Kartenbild gleich: 4:3, füllend zugeschnitten. Ohne Bild (Ideenkarten) oder bei
/// Ladefehlern eine gleich große Kachel in Designfarben – keine Emojis mehr.
struct KartenBild: View {
    let karte: Karte
    var ecken: CGFloat = 12
    var klein = false

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay { inhalt }
            .overlay(alignment: .bottomLeading) {
                // Ideenkarten zeigen nur ein passendes Beispiel, nicht das exakte Produkt.
                if karte.istBeispielbild && !klein {
                    Text("Beispielbild")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ecken))
    }

    @ViewBuilder private var inhalt: some View {
        if let adresse = karte.bildURL, let url = URL(string: adresse) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let bild): bild.resizable().scaledToFill()
                case .failure: kachel
                default: ZStack { Look.karte; ProgressView().tint(Look.akzent) }
                }
            }
        } else {
            kachel
        }
    }

    private var kachel: some View {
        ZStack {
            LinearGradient(colors: [Look.rand, Look.karte], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: klein ? 2 : 8) {
                Image(systemName: karte.istIdee ? "lightbulb" : "gift")
                    .font(klein ? .body : .system(size: 44))
                    .foregroundStyle(Look.akzent)
                if !klein {
                    Text(karte.titel)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .foregroundStyle(Look.text)
                        .padding(.horizontal, 20)
                }
            }
        }
    }
}
