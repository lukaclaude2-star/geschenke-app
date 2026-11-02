import Foundation

/// Geburtstag ohne Jahr – mehr braucht der Countdown nicht (Grundbaustein 10: datensparsam).
public struct Geburtstag: Codable, Equatable {
    public var tag: Int
    public var monat: Int

    public init(tag: Int, monat: Int) {
        self.tag = tag
        self.monat = monat
    }
}

public enum AnlassArt: Equatable {
    case weihnachten
    case geburtstag(profilID: UUID, name: String)
}

public struct Anlass: Equatable {
    public let art: AnlassArt
    public let tage: Int

    public init(art: AnlassArt, tage: Int) {
        self.art = art
        self.tage = tage
    }
}

private func istSchaltjahr(_ jahr: Int) -> Bool {
    (jahr % 4 == 0 && jahr % 100 != 0) || jahr % 400 == 0
}

/// Tage bis zum nächsten tag.monat (heute = 0). Der 29.02. zählt in Nicht-Schaltjahren als 28.02.
public func tageBis(tag: Int, monat: Int, heute: Date, kalender: Calendar = .current) -> Int {
    let start = kalender.startOfDay(for: heute)
    let jahr = kalender.component(.year, from: start)
    for j in [jahr, jahr + 1] {
        let t = (monat == 2 && tag == 29 && !istSchaltjahr(j)) ? 28 : tag
        guard let ziel = kalender.date(from: DateComponents(year: j, month: monat, day: t)) else { continue }
        if ziel >= start {
            return kalender.dateComponents([.day], from: start, to: ziel).day ?? 0
        }
    }
    return 0
}

/// Der nächste Anlass: Weihnachten (24.12.) oder ein eingetragener Geburtstag; bei Gleichstand der Geburtstag.
public func naechsterAnlass(heute: Date, profile: [GespeichertesProfil], kalender: Calendar = .current) -> Anlass {
    var bester = Anlass(art: .weihnachten, tage: tageBis(tag: 24, monat: 12, heute: heute, kalender: kalender))
    for p in profile {
        guard let g = p.geburtstag else { continue }
        let tage = tageBis(tag: g.tag, monat: g.monat, heute: heute, kalender: kalender)
        let istWeihnachten = bester.art == .weihnachten
        if tage < bester.tage || (tage == bester.tage && istWeihnachten) {
            bester = Anlass(art: .geburtstag(profilID: p.id, name: p.name), tage: tage)
        }
    }
    return bester
}

/// Schriftgröße der ganzen App (Einstellungen).
public enum Schriftstufe: String, CaseIterable, Identifiable {
    case klein, normal, gross, sehrGross

    public var id: String { rawValue }

    public var titel: String {
        switch self {
        case .klein: return "Klein"
        case .normal: return "Normal"
        case .gross: return "Groß"
        case .sehrGross: return "Sehr groß"
        }
    }

    public static func aus(_ rohwert: String) -> Schriftstufe {
        Schriftstufe(rawValue: rohwert) ?? .normal
    }
}
