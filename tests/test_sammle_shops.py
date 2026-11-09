from scripts.sammle_shops import _kandidaten


def test_nur_seiten_der_deutschen_sprachversion():
    seiten = ["https://www.11teamsports.com/it-it/scarpe/p/1", "https://www.11teamsports.com/de-de/schuhe/p/2",
              "https://www.11teamsports.com/DE-DE/ball/p/3"]
    assert sorted(_kandidaten(seiten, "https://www.11teamsports.com/de-de/")) == [
        "https://www.11teamsports.com/DE-DE/ball/p/3", "https://www.11teamsports.com/de-de/schuhe/p/2"]


def test_ohne_sprachpfad_alles_vom_shop():
    seiten = ["https://shop.de/a", "https://andererhost.de/b", "https://shop.de/bild.jpg"]
    assert _kandidaten(seiten, "https://www.shop.de/") == ["https://shop.de/a"]


def test_ohne_sprachpfad_keine_fremdsprachigen_seiten():
    """Deutsch ohne Präfix, andere Sprachen unter /en/, /fr/ … (z. B. VBS Hobby, Rosen Tantau)."""
    seiten = ["https://shop.de/rose-1", "https://shop.de/en/rose-2", "https://shop.de/fr-fr/rose-3",
              "https://shop.de/de/rose-4", "https://shop.de/eng/rose-5"]
    assert sorted(_kandidaten(seiten, "https://www.shop.de/")) == [
        "https://shop.de/de/rose-4", "https://shop.de/eng/rose-5", "https://shop.de/rose-1"]



import httpx
import pytest
import respx

from scripts import sammle_shops
from scripts.sammle_shops import MAX_CRAWL_DELAY, robots

UA = sammle_shops.KOPF["User-Agent"]


@pytest.fixture(autouse=True)
def ohne_pause(monkeypatch):
    monkeypatch.setattr(sammle_shops, "PAUSE", 0)


async def _robots(antwort):
    with respx.mock:
        route = respx.get("https://shop.de/robots.txt")
        if isinstance(antwort, Exception):
            route.mock(side_effect=antwort)
        else:
            route.mock(return_value=antwort)
        async with httpx.AsyncClient() as client:
            return await robots(client, "https://shop.de/")


async def test_robots_404_erlaubt_alles():
    regeln, _, _ = await _robots(httpx.Response(404))
    assert regeln.can_fetch(UA, "https://shop.de/produkt/1")


async def test_robots_5xx_verbietet_alles():
    regeln, _, _ = await _robots(httpx.Response(503))
    assert not regeln.can_fetch(UA, "https://shop.de/produkt/1")


async def test_robots_nicht_erreichbar_verbietet_alles():
    regeln, _, _ = await _robots(httpx.ConnectError("weg"))
    assert not regeln.can_fetch(UA, "https://shop.de/produkt/1")


async def test_robots_liest_regeln_sitemaps_und_crawl_delay():
    text = "User-agent: *\nDisallow: /privat/\nCrawl-delay: 3\nSitemap: https://shop.de/s.xml\n"
    regeln, sitemaps, pause = await _robots(httpx.Response(200, text=text))
    assert not regeln.can_fetch(UA, "https://shop.de/privat/x")
    assert regeln.can_fetch(UA, "https://shop.de/produkt/1")
    assert sitemaps == ["https://shop.de/s.xml"]
    assert pause == 3


async def test_robots_ohne_crawl_delay_normale_pause():
    _, _, pause = await _robots(httpx.Response(200, text="User-agent: *\nDisallow:\n"))
    assert pause == sammle_shops.PAUSE


async def test_zu_langer_crawl_delay_ueberspringt_shop():
    with respx.mock:
        respx.get("https://shop.de/").mock(return_value=httpx.Response(200, text="<html></html>"))
        respx.get("https://shop.de/robots.txt").mock(return_value=httpx.Response(
            200, text=f"User-agent: *\nCrawl-delay: {MAX_CRAWL_DELAY + 1}\n"))
        bericht = await sammle_shops.sammle({"name": "Shop", "url": "https://shop.de/"})
    assert bericht["status"].startswith("Crawl-delay")
    assert bericht["produkte"] == []
