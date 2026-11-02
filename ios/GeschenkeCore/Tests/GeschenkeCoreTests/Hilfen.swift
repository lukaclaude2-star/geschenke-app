@testable import GeschenkeCore

func testProfil(_ wuensche: [(String, Double)] = [("garten", 1.0)]) -> Profil {
    Profil(
        zusammenfassung: "Oma",
        wuensche: wuensche.map { Wunsch(tag: $0.0, label: $0.0, gewicht: $0.1) },
        ausschluesse: [Ausschluss(schluessel: "farbe:schwarz", label: "Schwarz")],
        budgetMax: 50
    )
}

func testKarte(_ id: String = "a", tags: [String] = ["garten"]) -> Karte {
    Karte(id: id, art: "produkt", titel: "Hochbeet", preis: 34.9, preisVon: nil, preisBis: nil,
          bildURL: "https://x/b.jpg", emoji: nil, shop: "Shop", link: "https://x/a", tags: tags)
}
