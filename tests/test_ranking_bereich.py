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
