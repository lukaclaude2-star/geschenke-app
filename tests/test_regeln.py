from app.katalog.regeln import fasse_varianten_zusammen, pruefe_regeln
from app.modelle import QuellProdukt


def gut(**abweichung) -> QuellProdukt:
    werte = dict(
        id="p1", titel="Kräuter-Hochbeet aus Holz", beschreibung="x" * 80, preis=25.0,
        bild_url="https://shop.example/bild.jpg", link="https://shop.example/p1", shop="Shop",
        kategorie="Garten > Hochbeete",
    )
    werte.update(abweichung)
    return QuellProdukt(**werte)


def test_gutes_produkt_besteht(): assert pruefe_regeln(gut()) is None
def test_ohne_bild(): assert pruefe_regeln(gut(bild_url=None))
def test_leere_bild_url(): assert pruefe_regeln(gut(bild_url=""))
def test_bild_zu_klein(): assert pruefe_regeln(gut(bild_breite=200))
def test_bildbreite_unbekannt_besteht(): assert pruefe_regeln(gut(bild_breite=None)) is None
def test_beschreibung_zu_kurz(): assert pruefe_regeln(gut(beschreibung="Toller Becher"))
def test_unter_mindestpreis(): assert pruefe_regeln(gut(preis=7.99))
def test_genau_mindestpreis_besteht(): assert pruefe_regeln(gut(preis=8.0)) is None
def test_nicht_lieferbar(): assert pruefe_regeln(gut(lieferbar=False))
def test_gesperrte_kategorie_teilwort(): assert pruefe_regeln(gut(kategorie="Elektronik > USB-Kabel"))
def test_ohne_link(): assert pruefe_regeln(gut(link=""))


def test_varianten_behalten_guenstigste():
    a = gut(id="a", preis=30, varianten_gruppe="kissen")
    b = gut(id="b", preis=20, varianten_gruppe="kissen")
    assert [p.id for p in fasse_varianten_zusammen([a, b, gut(id="c")])] == ["b", "c"]
