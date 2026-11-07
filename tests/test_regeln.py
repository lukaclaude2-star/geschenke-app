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


def test_groessen_ohne_gruppe_werden_eine_karte():
    """Kleidungsshops liefern Größen oft als eigene Seiten ohne gemeinsame Gruppe."""
    ps = [gut(id="m", titel="Hoodie Classic – Größe M", preis=50),
          gut(id="l", titel="Hoodie Classic - L", preis=45),
          gut(id="xl", titel="Hoodie Classic (XL)", preis=55),
          gut(id="s", titel="Stiefel Berta Gr. 39/40", preis=90),
          gut(id="s2", titel="Stiefel Berta Größe 41", preis=95),
          gut(id="w1", titel="Whisky 18"), gut(id="w2", titel="Whisky 21")]
    assert [p.id for p in fasse_varianten_zusammen(ps)] == ["l", "s", "w1", "w2"]


def test_gleicher_titel_anderer_shop_bleibt_getrennt():
    ps = [gut(id="a", titel="Hoodie Classic M", shop="A"), gut(id="b", titel="Hoodie Classic M", shop="B")]
    assert [p.id for p in fasse_varianten_zusammen(ps)] == ["a", "b"]


def test_varianten_gruppe_aus_feed_hat_vorrang():
    ps = [gut(id="a", titel="Hoodie Classic M", varianten_gruppe="g1"),
          gut(id="b", titel="Hoodie Classic L", varianten_gruppe="g2")]
    assert [p.id for p in fasse_varianten_zusammen(ps)] == ["a", "b"]


def test_zahl_im_namen_ist_keine_groesse():
    ps = [gut(id="a", titel="Puzzle 1000 Teile"), gut(id="b", titel="Puzzle 500 Teile")]
    assert [p.id for p in fasse_varianten_zusammen(ps)] == ["a", "b"]


def test_buchstabe_am_wortende_ist_keine_groesse():
    from app.katalog.regeln import varianten_schluessel
    assert varianten_schluessel(gut(titel="Tasche Paris")) is None
    assert varianten_schluessel(gut(titel="Schal Uni")) is None
    assert varianten_schluessel(gut(titel="Hoodie XL")) == "Shop|hoodie"
