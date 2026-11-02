import httpx
import pytest
import respx

from app import bilder
from app import ideen as ideen_modul
from app.bilder import PEXELS_SUCHE, beispielbild
from app.config import settings
from app.ideen import ideen_karten
from app.modelle import Profil, Wunsch

TREFFER = {"photos": [{"src": {"large": "https://images.pexels.com/1-large.jpg",
                               "medium": "https://images.pexels.com/1-medium.jpg"}}]}


@pytest.fixture(autouse=True)
def frisch(monkeypatch):
    monkeypatch.setattr(settings, "pexels_key", "test-schluessel")
    bilder.leere_cache()


@respx.mock
async def test_treffer_liefert_grosses_bild():
    route = respx.get(PEXELS_SUCHE).mock(return_value=httpx.Response(200, json=TREFFER))
    assert await beispielbild("Gaming Headset") == "https://images.pexels.com/1-large.jpg"
    anfrage = route.calls.last.request
    assert anfrage.headers["Authorization"] == "test-schluessel"
    assert anfrage.url.params["query"] == "Gaming Headset"


@respx.mock
async def test_cache_fragt_nur_einmal():
    route = respx.get(PEXELS_SUCHE).mock(return_value=httpx.Response(200, json=TREFFER))
    await beispielbild("Grillthermometer")
    await beispielbild("grillthermometer ")
    assert route.call_count == 1


@respx.mock
async def test_ohne_schluessel_keine_anfrage(monkeypatch):
    monkeypatch.setattr(settings, "pexels_key", "")
    route = respx.get(PEXELS_SUCHE).mock(return_value=httpx.Response(200, json=TREFFER))
    assert await beispielbild("Gaming Headset") is None
    assert route.call_count == 0


@respx.mock
async def test_fehler_und_leere_treffer_ergeben_none():
    respx.get(PEXELS_SUCHE).mock(side_effect=[httpx.Response(500), httpx.ConnectTimeout("weg"),
                                              httpx.Response(200, json={"photos": []}),
                                              httpx.Response(200, text="kein json")])
    for begriff in ("a", "b", "c", "d"):
        assert await beispielbild(begriff) is None


@respx.mock
async def test_ideenkarte_bekommt_beispielbild(monkeypatch):
    respx.get(PEXELS_SUCHE).mock(return_value=httpx.Response(200, json=TREFFER))

    async def ki(*_, **__):
        return {"ideen": [{"titel": "Gaming-Headset", "emoji": "🎧", "preis_von": 30, "preis_bis": 60,
                           "suchbegriff": "Gaming Headset", "themen": ["gaming"]}]}
    monkeypatch.setattr(ideen_modul, "frage_json", ki)
    profil = Profil(zusammenfassung="Papa", ausschluesse=[], wuensche=[Wunsch(tag="gaming", label="g", gewicht=1)])
    [karte] = await ideen_karten(profil, 3, set())
    assert karte.bild_url == "https://images.pexels.com/1-large.jpg"
    assert karte.beispielbild is True
    assert karte.art == "idee"
