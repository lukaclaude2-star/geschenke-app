import GeschenkeCore
import SwiftUI

/// Ein Dokument aus `rechtliches.json` (Impressum, Datenschutz, …). Die Datei steckt in der App,
/// deshalb geht das auch, wenn der Server schläft (Impressum in zwei Tippern, § 5 DDG).
struct RechtstextView: View {
    let dokumentID: String

    var body: some View {
        let dokument = AppZustand.rechtstexte?.dokument(dokumentID)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let dokument {
                    ForEach(Array(dokument.abschnitte.enumerated()), id: \.offset) { _, abschnitt in
                        VStack(alignment: .leading, spacing: 8) {
                            if let ueberschrift = abschnitt.ueberschrift {
                                Text(ueberschrift).font(.titel(.headline)).foregroundStyle(Look.text)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            ForEach(Array(abschnitt.absaetze.enumerated()), id: \.offset) { _, absatz in
                                absatzZeile(absatz)
                            }
                        }
                    }
                } else {
                    Text("Der Text ließ sich nicht laden. Du findest ihn auch auf geschenke.onrender.com/\(dokumentID).")
                        .foregroundStyle(Look.leise)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .zuhauseHintergrund()
        .navigationTitle(dokument?.titel ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func absatzZeile(_ absatz: String) -> some View {
        if absatz.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(Look.leise).accessibilityHidden(true)
                ZuhauseMarkdown(text: String(absatz.dropFirst(2)))
            }
        } else {
            ZuhauseMarkdown(text: absatz)
        }
    }
}

/// Fließtext mit `**fett**` und `[Link](https://…)`, wie er in den Rechtstexten steht.
struct ZuhauseMarkdown: View {
    let text: String

    var body: some View {
        let optionen = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let attributiert = (try? AttributedString(markdown: text, options: optionen)) ?? AttributedString(text)
        Text(attributiert)
            .font(.zuhause(.body))
            .foregroundStyle(Look.text)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Rechtstext als eigenes Blatt (aus der Zustimmung und vom Wischen aus).
struct RechtstextBlatt: View {
    let dokumentID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RechtstextView(dokumentID: dokumentID)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Fertig") { dismiss() } } }
        }
        .presentationBackground(Look.hintergrund)
    }
}
