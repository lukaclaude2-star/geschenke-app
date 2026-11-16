import json

import httpx
import pytest
import respx

from app.config import settings
from app.ki import GROQ_URL, KiUeberlastet, frage_json


def antwort(inhalt: str) -> httpx.Response:
    return httpx.Response(200, json={"choices": [{"message": {"content": inhalt}}]})


@respx.mock
async def test_liefert_geparstes_json():
    respx.post(GROQ_URL).mock(return_value=antwort('{"a": 1}'))
    assert await frage_json("sys", "nutzer") == {"a": 1}


@respx.mock
async def test_429_wechselt_auf_naechstes_modell():
    route = respx.post(GROQ_URL).mock(side_effect=[httpx.Response(429), antwort('{"ok": true}')])
    assert await frage_json("sys", "nutzer") == {"ok": True}
    modelle = [json.loads(c.request.content)["model"] for c in route.calls]
    assert modelle == settings.ki_modelle[:2]


@respx.mock
async def test_kaputtes_json_wird_wiederholt_dann_naechstes_modell():
    route = respx.post(GROQ_URL).mock(
        side_effect=[antwort("kein json"), antwort(""), antwort('{"x": 2}')]
    )
    assert await frage_json("sys", "nutzer") == {"x": 2}
    modelle = [json.loads(c.request.content)["model"] for c in route.calls]
    assert modelle == [settings.ki_modelle[0], settings.ki_modelle[0], settings.ki_modelle[1]]


@respx.mock
async def test_alle_modelle_erschoepft_wirft_kiueberlastet():
    respx.post(GROQ_URL).mock(return_value=httpx.Response(503))
    with pytest.raises(KiUeberlastet):
        await frage_json("sys", "nutzer")


@respx.mock
async def test_netzwerkfehler_wird_kiueberlastet():
    respx.post(GROQ_URL).mock(side_effect=httpx.ConnectError("weg"))
    with pytest.raises(KiUeberlastet):
        await frage_json("sys", "nutzer")


@respx.mock
async def test_schickt_keine_geraetekennung():
    route = respx.post(GROQ_URL).mock(return_value=antwort("{}"))
    await frage_json("sys", "nutzer")
    body = json.loads(route.calls[0].request.content)
    erlaubt = {"model", "messages", "temperature", "max_tokens", "response_format",
               "reasoning_effort", "reasoning_format"}
    assert set(body) <= erlaubt
    assert body["response_format"] == {"type": "json_object"}



@respx.mock
async def test_eigene_kette_je_aufruf():
    route = respx.post(GROQ_URL).mock(side_effect=[httpx.Response(429), antwort('{"ok": 1}')])
    assert await frage_json("sys", "n", modelle=["a", "b"]) == {"ok": 1}
    assert [json.loads(c.request.content)["model"] for c in route.calls] == ["a", "b"]


@respx.mock
async def test_unbrauchbare_antwort_wechselt_auf_naechstes_modell():
    route = respx.post(GROQ_URL).mock(side_effect=[antwort("{}"), antwort('{"x": 1}')])
    assert await frage_json("sys", "nutzer", brauchbar=bool) == {"x": 1}
    modelle = [json.loads(c.request.content)["model"] for c in route.calls]
    assert modelle == settings.ki_modelle[:2]


@respx.mock
async def test_nur_unbrauchbare_antworten_liefert_die_erste():
    respx.post(GROQ_URL).mock(side_effect=[antwort('{"a": 1}'), antwort('{"b": 2}'), antwort('{"c": 3}')])
    assert await frage_json("sys", "nutzer", brauchbar=lambda _: False) == {"a": 1}


async def test_zeitlimit_liefert_die_unbrauchbare_antwort(monkeypatch):
    import asyncio

    from app import ki

    async def kette(*args):
        args[-1].append({"a": 1})
        await asyncio.sleep(1)
    monkeypatch.setattr(ki, "_kette", kette)
    assert await frage_json("sys", "nutzer", zeitlimit=0.05, brauchbar=bool) == {"a": 1}
