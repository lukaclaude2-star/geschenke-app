from app.ranking import BEREICH_ANTEIL, bewerte, kandidaten
from tests.test_ranking import produkt, profil


def test_oberbereich_zaehlt_schwaecher():
    assert BEREICH_ANTEIL == 0.4
    p = profil(wuensche=(("whisky", 1.0),))
    assert bewerte(produkt("w", themen=("whisky",)), p) == 1.0
    assert bewerte(produkt("v", themen=("wein",)), p) == 0.4


def test_anderer_bereich_kein_kandidat():
    p = profil(wuensche=(("whisky", 1.0),))
    assert kandidaten([produkt("g", themen=("garten",))], p, set()) == []


def test_kein_doppelzaehlen():
    p = profil(wuensche=(("whisky", 1.0),))
    assert bewerte(produkt("b", themen=("whisky", "wein", "gin")), p) == 1.0


def test_unbekannter_tag_kein_absturz():
    p = profil(wuensche=(("gibtsnicht", 1.0), ("whisky", 1.5)))
    assert bewerte(produkt("v", themen=("wein",)), p) == 0.6


def test_lebenslage_hat_keinen_bereich():
    p = profil(wuensche=(("umzug", 1.0),))
    assert bewerte(produkt("u", themen=("wohnen",), lebenslagen=["umzug"]), p) == 1.0
    assert bewerte(produkt("x", themen=("wohnen",)), p) == 0


def test_bereich_treffer_ueberholen_keine_echten_treffer():
    """Review-Befund: grillen/kochen/backen/gaming – Pizza-Zeug darf Gaming nicht verdrängen."""
    from app.ranking import waehle_karten
    p = profil(wuensche=(("grillen", 1.0), ("kochen", 1.0), ("backen", 1.0), ("gaming", 1.0)))
    assert bewerte(produkt("pizza", themen=("pizza",)), p) == 0.4
    assert bewerte(produkt("koch", themen=("kochen",)), p) == 1.0
    katalog = [produkt(f"k{i}", themen=("pizza",)) for i in range(12)] + \
              [produkt(f"g{i}", themen=("gaming",)) for i in range(5)]
    karten, _ = waehle_karten(katalog, p, set(), 10)
    assert sum(1 for k in karten if k.id.startswith("g")) == 5
