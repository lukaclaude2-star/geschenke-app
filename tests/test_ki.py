import json

import httpx
import pytest
import respx

from app.config import settings
from app.ki import GITHUB_MODELS_URL, GROQ_URL, KiUeberlastet, frage_json


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
async def test_github_modell_geht_an_github_mit_eigenem_schluessel(monkeypatch):
    monkeypatch.setattr(settings, "github_models_token", "gh-test")
    groq = respx.post(GROQ_URL).mock(return_value=httpx.Response(429))
    github = respx.post(GITHUB_MODELS_URL).mock(return_value=antwort('{"ok": 1}'))
    assert await frage_json("sys", "n", modelle=["qwen/qwen3.8-27b", "github:openai/gpt-4.1-mini"]) == {"ok": 1}
    anfrage = github.calls[0].request
    body = json.loads(anfrage.content)
    assert body["model"] == "openai/gpt-4.1-mini" and "reasoning_format" not in body
    assert anfrage.headers["authorization"] == "Bearer gh-test"
    assert "gh-test" not in groq.calls[0].request.headers["authorization"]
