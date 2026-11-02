import Foundation

/// Der Budget-Regler im Chat: zwei Griffe auf festen Stufen (Grundbaustein 7, Ausnahme).
/// Unten feiner, weil dort ein paar Euro mehr ins Gewicht fallen.
public enum BudgetSkala {
    public static let minimum: Double = 5
    public static let maximum: Double = 500

    /// 5–100 in 5er-Schritten, darüber in 25er-Schritten bis 500.
    public static let stufen: [Double] =
        Array(stride(from: 5.0, through: 100, by: 5)) + Array(stride(from: 125.0, through: 500, by: 25))

    /// Griff ganz links = keine Untergrenze, ganz rechts = keine Obergrenze.
    public static func grenzen(von: Double, bis: Double) -> (min: Double?, max: Double?) {
        (von <= minimum ? nil : von, bis >= maximum ? nil : bis)
    }

    public static func text(von: Double?, bis: Double?) -> String {
        switch (von, bis) {
        case let (v?, b?): return "Budget: \(zahl(v))–\(zahl(b)) €"
        case let (v?, nil): return "Budget: ab \(zahl(v)) €"
        case let (nil, b?): return "Budget: bis \(zahl(b)) €"
        default: return "Budget: egal"
        }
    }

    /// Nächstgelegene Stufe – auch für Werte, die nicht genau auf einer Stufe liegen (z. B. von der KI).
    public static func index(nahe wert: Double) -> Int {
        stufen.indices.min { abs(stufen[$0] - wert) < abs(stufen[$1] - wert) } ?? 0
    }

    /// Startstellung der Griffe aus einem Profil: vertauschte oder gleiche Grenzen werden so
    /// gelegt, dass „von“ immer mindestens eine Stufe links von „bis“ liegt.
    public static func startwerte(min: Double?, max: Double?) -> (von: Double, bis: Double) {
        let letzte = stufen.count - 1
        var iv = index(nahe: min ?? minimum)
        var ib = index(nahe: max ?? maximum)
        if iv > ib { swap(&iv, &ib) }
        if iv == ib {
            if ib < letzte { ib += 1 } else { iv -= 1 }
        }
        return (stufen[iv], stufen[ib])
    }

    /// Gezogener „von“-Griff: bleibt links vom „bis“-Griff.
    public static func vonIndex(gezogen: Int, bisIndex: Int) -> Int {
        Swift.max(0, Swift.min(gezogen, bisIndex - 1))
    }

    /// Gezogener „bis“-Griff: bleibt rechts vom „von“-Griff.
    public static func bisIndex(gezogen: Int, vonIndex: Int) -> Int {
        Swift.min(stufen.count - 1, Swift.max(gezogen, vonIndex + 1))
    }

    static func zahl(_ wert: Double) -> String {
        String(Int(wert.rounded()))
    }
}
