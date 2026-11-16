"""Partnerlinks werden als „Anzeige“ gekennzeichnet (§ 5a Abs. 4 UWG; Plan 2026-11-05, Task 3)."""

import pytest

from app.config import settings
from app.ideen import ideen_karten
from app.karten import produkt_zu_karte
from app.partnerlinks import ist_partnerlink, mit_partnerlink
from tests.test_karten import FakeKi, produkt, profil
from app import ideen as ideen_modul


@pytest.mark.parametrize("link", [
    "https://www.awin1.com/cread.php?awinmid=1&awinaffid=2&ued=https%3A%2F%2Fshop.de",
    "https://awin1.com/pclick.php?p=1",
    "https://clk.tradedoubler.com/click?p=1&a=2",
    "https://www.amazon.de/s?k=kniekissen&tag=luka-21",
    "https://amazon.de/dp/B000?tag=luka-21",
    "https://amzn.to/3abc",
])
def test_partnerlink_erkannt(link):
    assert ist_partnerlink(link)


@pytest.mark.parametrize("link", [
    "https://www.grillfuerst.de/p/1",
    "https://www.amazon.de/s?k=kniekissen",
    "https://evil-awin1.com/cread.php",
    "https://awin1.com.evil.de/x",
    "https://shop.de/?ref=awin1.com",
    "",
    "kaputt",
])
def test_normaler_link_keine_anzeige(link):
    assert not ist_partnerlink(link)


def test_produktkarte_mit_awin_ist_anzeige():
    karte = produkt_zu_karte(produkt("a", link="https://www.awin1.com/cread.php?awinmid=1"))
    assert karte.anzeige is True


def test_produktkarte_ohne_partner_ist_keine_anzeige():
    assert produkt_zu_karte(produkt("a")).anzeige is False


async def test_ideenkarte_mit_amazon_tag_ist_anzeige(monkeypatch):
    monkeypatch.setattr(ideen_modul, "frage_json", FakeKi())
    monkeypatch.setattr(settings, "amazon_tag", "luka-21")
    karten = await ideen_karten(profil(), 2, set())
    assert karten and all(k.anzeige for k in karten)


@pytest.fixture
def awin(monkeypatch):
    monkeypatch.setattr(settings, "awin_publisher_id", "999")
    monkeypatch.setattr(settings, "awin_programme", {"grillfuerst.de": 123, "www.mydays.de": 456})


def test_shop_mit_programm_bekommt_awin_deeplink(awin):
    link = mit_partnerlink("https://www.grillfuerst.de/p/1?farbe=rot")
    assert link == ("https://www.awin1.com/cread.php?awinmid=123&awinaffid=999"
                    "&ued=https%3A%2F%2Fwww.grillfuerst.de%2Fp%2F1%3Ffarbe%3Drot")
    assert ist_partnerlink(link)


def test_programm_eintrag_mit_www_passt_auch(awin):
    assert "awinmid=456" in mit_partnerlink("https://mydays.de/x")


@pytest.mark.parametrize("link", [
    "https://www.santosgrills.de/p/1",  # kein Programm
    "https://grillfuerst.de.evil.de/p/1",  # nur ähnlich
    "https://www.awin1.com/cread.php?awinmid=1&awinaffid=2",  # schon ein Partnerlink
    "",
])
def test_andere_links_bleiben(awin, link):
    assert mit_partnerlink(link) == link


def test_ohne_publisher_id_bleibt_alles_normal(monkeypatch):
    monkeypatch.setattr(settings, "awin_publisher_id", "")
    monkeypatch.setattr(settings, "awin_programme", {"grillfuerst.de": 123})
    assert mit_partnerlink("https://www.grillfuerst.de/p/1") == "https://www.grillfuerst.de/p/1"


def test_produktkarte_wird_mit_programm_zur_anzeige(awin):
    karte = produkt_zu_karte(produkt("a", link="https://www.grillfuerst.de/p/1"))
    assert karte.link.startswith("https://www.awin1.com/cread.php?awinmid=123")
    assert karte.anzeige is True


def test_programme_kommen_als_json_aus_der_umgebung(monkeypatch):
    from app.config import Settings
    monkeypatch.setenv("AWIN_PROGRAMME", '{"bergfreunde.de": 12345}')
    assert Settings().awin_programme == {"bergfreunde.de": 12345}


async def test_ideenkarte_ohne_tag_ist_keine_anzeige(monkeypatch):
    monkeypatch.setattr(ideen_modul, "frage_json", FakeKi())
    monkeypatch.setattr(settings, "amazon_tag", "")
    karten = await ideen_karten(profil(), 2, set())
    assert karten and not any(k.anzeige for k in karten)
