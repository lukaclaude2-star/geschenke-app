import GeschenkeCore
import SwiftUI

/// Zustimmung, bevor zum ersten Mal etwas an den Server und die KI geht (Apple 5.1.2(i): fremde KI
/// nur nach ausdrücklicher Erlaubnis; EU AI Act Art. 50: Hinweis, dass hier eine KI antwortet).
/// Was hier steht, muss zur Datenschutzerklärung passen. Ändert sich, was an wen geht:
/// `AppDaten.kiEinwilligungVersion` erhöhen, dann fragt die App erneut.
struct KiEinwilligungView: View {
    let fertig: (Bool) -> Void
    @Environment(\.dynamicTypeSize) private var schriftgroesse
    @State private var zeigeDatenschutz = false

    private let punkte = [
        "**Du schreibst mit einer KI.** Was du über die Person erzählst, schickt die App an ihren Server in Frankfurt und von dort an den KI-Dienst Groq in den USA. Der Server speichert davon nichts, Groq höchstens 30 Tage zur Abwehr von Missbrauch.",
        "**Für die Vorschläge** geht auch die Beschreibung der Person mit: Wünsche (mit dem, was die App beim Wischen gelernt hat), Ausschlüsse und Budget. Nie der Name, unter dem du sie speicherst, und nie eine Gerätekennung.",
        "**Produktfotos** lädt die App direkt von den Shops. Die sehen dabei, wie bei jeder Webseite, deine IP-Adresse.",
        "**Bitte keine** vollständigen Namen, Adressen oder Angaben zur Gesundheit. „Meine Oma, 70, gärtnert gern“ reicht völlig.",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !schriftgroesse.isAccessibilitySize {
                        Image("coco-katze").resizable().scaledToFit().frame(height: 110)
                            .frame(maxWidth: .infinity).accessibilityHidden(true)
                    }
                    Text("bevor wir loslegen.").font(.titel(.title)).foregroundStyle(Look.text)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(punkte, id: \.self) { ZuhauseMarkdown(text: $0) }
                    Text("Du kannst die Zustimmung jederzeit in den Einstellungen widerrufen.")
                        .font(.zuhause(.footnote)).foregroundStyle(Look.leise)
                    Button { zeigeDatenschutz = true } label: {
                        Text("Datenschutzerklärung lesen").font(.zuhause(.body, .fett))
                            .foregroundStyle(Look.akzentText).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 10) {
                Button("Einverstanden") { fertig(true) }.buttonStyle(GoldKnopf())
                Button("Nicht jetzt") { fertig(false) }.buttonStyle(RandKnopf())
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .zuhauseHintergrund()
        .sheet(isPresented: $zeigeDatenschutz) { RechtstextBlatt(dokumentID: "datenschutz") }
    }
}

/// Zeigt statt des Inhalts die Zustimmung, bis sie gegeben ist. So startet der Inhalt (und damit
/// jede Anfrage an den Server) erst danach. „Nicht jetzt“ geht einen Schritt zurück.
private struct KiEinwilligungsTor: ViewModifier {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.dismiss) private var dismiss

    @ViewBuilder func body(content: Content) -> some View {
        if zustand.daten.hatKiEinwilligung {
            content
        } else {
            KiEinwilligungView { ja in
                if ja { zustand.setzeKiEinwilligung(true) } else { dismiss() }
            }
        }
    }
}

extension View {
    /// Für alle Ansichten, die beim Erscheinen den Server oder die KI fragen.
    func brauchtKiEinwilligung() -> some View {
        modifier(KiEinwilligungsTor())
    }
}
