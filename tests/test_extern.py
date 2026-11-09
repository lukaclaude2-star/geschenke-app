import json

import httpx
import pytest
import respx

from app.config import settings
from app.katalog import verschlagworten
from app.katalog.extern import ANBIETER, frage_json_extern
from app.ki import KiUeberlastet
from tests.test_verschlagworten import FakeKi, produkt

NVIDIA_URL = ANBIETER["nvidia"][0]


def antwort(inhalt: str) -> httpx.Response:
    return httpx.Response(200, json={"choices": [{"message": {"content": inhalt}}]})


@respx.mock
async def test_nvidia_liefert_json(monkeypatch):
    monkeypatch.setattr(settings, "nvidia_api_key", "geheim")
    route = respx.post(NVIDIA_URL).mock(return_value=antwort('{"a": 1}'))
    assert await frage_json_extern("sys", "nutzer", anbieter="nvidia", modell="m") == {"a": 1}
    anfrage = route.calls[0].request
    assert anfrage.headers["Authorization"] == "Bearer geheim"
    rumpf = json.loads(anfrage.content)
    assert rumpf["model"] == "m" and rumpf["response_format"] == {"type": "json_object"}


def test_nvidia_adresse():
    assert NVIDIA_URL == "https://integrate.api.nvidia.com/v1/chat/completions"


@respx.mock
async def test_429_wirft_ueberlastet():
    respx.post(NVIDIA_URL).mock(return_value=httpx.Response(429))
    with pytest.raises(KiUeberlastet):
        await frage_json_extern("sys", "nutzer", anbieter="nvidia", modell="m")


@respx.mock
async def test_kaputtes_json_einmal_wiederholt():
    route = respx.post(NVIDIA_URL).mock(side_effect=[antwort("x"), antwort('{"b": 2}')])
    assert await frage_json_extern("sys", "nutzer", anbieter="nvidia", modell="m") == {"b": 2}
    assert route.call_count == 2


@respx.mock
async def test_zweimal_kaputt_wirft_ueberlastet():
    respx.post(NVIDIA_URL).mock(side_effect=[antwort("x"), antwort("")])
    with pytest.raises(KiUeberlastet):
        await frage_json_extern("sys", "nutzer", anbieter="nvidia", modell="m")


@respx.mock
async def test_zeitueberschreitung_wirft_ueberlastet():
    respx.post(NVIDIA_URL).mock(side_effect=httpx.ReadTimeout("langsam"))
    with pytest.raises(KiUeberlastet):
        await frage_json_extern("sys", "nutzer", anbieter="nvidia", modell="m")


async def test_stapel_mit_externem_arbeiter_fragt_anbieter(monkeypatch):
    fake, aufrufe = FakeKi(), []

    async def extern(system, nutzer, *, anbieter, modell, **_):
        aufrufe.append((anbieter, modell))
        return await fake(system, nutzer)

    async def groq(*_, **__):
        raise AssertionError("Externer Arbeiter darf nicht Groq fragen")
    monkeypatch.setattr(verschlagworten, "frage_json_extern", extern)
    monkeypatch.setattr(verschlagworten, "frage_json", groq)
    ergebnis = await verschlagworten._stapel([produkt("1"), produkt("2")], "nvidia:google/gemma-4-31b-it#3")
    assert [p.id for p in ergebnis] == ["1", "2"] and aufrufe == [("nvidia", "google/gemma-4-31b-it")]


def test_arbeiter_ohne_nvidia_schluessel_wie_bisher(monkeypatch):
    from scripts.build_katalog import PAUSE_GROQ, arbeiter
    monkeypatch.setattr(settings, "nvidia_api_key", "")
    assert arbeiter() == {m: PAUSE_GROQ for m in settings.ki_modelle[1:]}


def test_arbeiter_mit_nvidia_schluessel(monkeypatch):
    from scripts.build_katalog import PAUSE_EXTERN, arbeiter
    monkeypatch.setattr(settings, "nvidia_api_key", "geheim")
    assert settings.nvidia_modelle == ["minimaxai/minimax-m3.1-flash"]
    assert settings.nvidia_arbeiter_je_modell == 3
    # Nur NVIDIA: Groq-Kontingent bleibt für die App frei
    assert arbeiter() == {f"nvidia:minimaxai/minimax-m3.1-flash#{n}": PAUSE_EXTERN for n in range(3)}


def test_groq_nur_als_ersatz_wenn_nvidia_nichts_schafft():
    from scripts.build_katalog import braucht_ersatz
    nvidia = {"nvidia:m#0": 5}
    assert braucht_ersatz(nvidia, {"neu_verschlagwortet": 0, "noch_offen": 40})
    assert not braucht_ersatz(nvidia, {"neu_verschlagwortet": 20, "noch_offen": 20})
    assert not braucht_ersatz(nvidia, {"neu_verschlagwortet": 0, "noch_offen": 0})
    assert not braucht_ersatz({"openai/gpt-oss-20b": 55}, {"neu_verschlagwortet": 0, "noch_offen": 40})
