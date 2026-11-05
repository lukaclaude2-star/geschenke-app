"""Partnerlinks werden als „Anzeige“ gekennzeichnet (§ 5a Abs. 4 UWG; Plan 2026-11-05, Task 3)."""

import pytest

from app.config import settings
from app.ideen import ideen_karten
from app.karten import produkt_zu_karte
from app.partnerlinks import ist_partnerlink
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


async def test_ideenkarte_ohne_tag_ist_keine_anzeige(monkeypatch):
    monkeypatch.setattr(ideen_modul, "frage_json", FakeKi())
    monkeypatch.setattr(settings, "amazon_tag", "")
    karten = await ideen_karten(profil(), 2, set())
    assert karten and not any(k.anzeige for k in karten)
