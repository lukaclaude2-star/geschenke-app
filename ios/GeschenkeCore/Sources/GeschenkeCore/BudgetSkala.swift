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

    static func zahl(_ wert: Double) -> String {
        String(Int(wert.rounded()))
    }
}
