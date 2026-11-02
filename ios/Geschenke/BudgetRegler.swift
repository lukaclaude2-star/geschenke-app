import GeschenkeCore
import SwiftUI

/// Regler mit zwei Griffen (von / bis) auf den Stufen der `BudgetSkala`.
/// Links am Anschlag = keine Untergrenze, rechts am Anschlag = keine Obergrenze.
struct BudgetRegler: View {
    @Binding var von: Double
    @Binding var bis: Double
    private let stufen = BudgetSkala.stufen
    private let griff: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let grenzen = BudgetSkala.grenzen(von: von, bis: bis)
            Text(BudgetSkala.text(von: grenzen.min, bis: grenzen.max).replacingOccurrences(of: "Budget: ", with: ""))
                .font(.title3.bold())
                .foregroundStyle(Look.preis)
            GeometryReader { geo in
                let breite = max(1, geo.size.width - griff)
                let iv = index(von), ib = index(bis)
                ZStack(alignment: .leading) {
                    Capsule().fill(Look.rand).frame(height: 4)
                        .padding(.horizontal, griff / 2)
                    Capsule().fill(Look.akzent)
                        .frame(width: x(ib, breite) - x(iv, breite), height: 4)
                        .offset(x: griff / 2 + x(iv, breite))
                    knopf.offset(x: x(iv, breite))
                        .gesture(ziehen(breite) { neu in von = stufen[min(neu, index(bis) - 1)] })
                    knopf.offset(x: x(ib, breite))
                        .gesture(ziehen(breite) { neu in bis = stufen[max(neu, index(von) + 1)] })
                }
                .coordinateSpace(.named("budget"))
            }
            .frame(height: griff)
            HStack {
                Text("\(Int(BudgetSkala.minimum)) €")
                Spacer()
                Text("\(Int(BudgetSkala.maximum)) €+")
            }
            .font(.caption2)
            .foregroundStyle(Look.leise)
        }
    }

    private var knopf: some View {
        Circle()
            .fill(Look.akzent)
            .overlay(Circle().stroke(Look.aufAkzent, lineWidth: 2))
            .frame(width: griff, height: griff)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }

    private func x(_ i: Int, _ breite: CGFloat) -> CGFloat {
        CGFloat(i) / CGFloat(stufen.count - 1) * breite
    }

    /// Nächstgelegene Stufe – auch für Werte, die nicht genau auf einer Stufe liegen (z. B. von der KI).
    private func index(_ wert: Double) -> Int {
        stufen.indices.min { abs(stufen[$0] - wert) < abs(stufen[$1] - wert) } ?? 0
    }

    private func ziehen(_ breite: CGFloat, setze: @escaping (Int) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("budget"))
            .onChanged { wert in
                let anteil = (wert.location.x - griff / 2) / breite
                let i = Int((anteil * CGFloat(stufen.count - 1)).rounded())
                setze(min(stufen.count - 1, max(0, i)))
            }
    }
}
