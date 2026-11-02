import SwiftUI

struct LaengeView: View {
    private struct Laenge: Identifiable {
        let id: String
        let titel: String
        let untertitel: String
    }

    private let laengen = [
        Laenge(id: "schnell", titel: "Schnell", untertitel: "ca. 3 Fragen"),
        Laenge(id: "normal", titel: "Normal", untertitel: "ca. 5 Fragen"),
        Laenge(id: "gruendlich", titel: "Gründlich", untertitel: "ca. 8 Fragen"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Wie viel Zeit hast du?")
                .font(.title2.bold())
            Text("Je mehr du erzählst, desto besser passen die Vorschläge.")
                .foregroundStyle(Look.leise)
                .multilineTextAlignment(.center)
            ForEach(laengen) { laenge in
                NavigationLink {
                    ChatView(laenge: laenge.id)
                } label: {
                    VStack(spacing: 2) {
                        Text(laenge.titel)
                        Text(laenge.untertitel).font(.caption).opacity(0.8)
                    }
                }
                .buttonStyle(laenge.id == "normal" ? AnyButtonStyle(GoldKnopf()) : AnyButtonStyle(RandKnopf()))
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .nachtblau()
        .navigationTitle("Neue Suche")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let erzeuge: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ stil: S) {
        erzeuge = { AnyView(stil.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        erzeuge(configuration)
    }
}
