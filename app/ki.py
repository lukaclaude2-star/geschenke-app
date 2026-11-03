"""Groq mit einer Kette von Ersatzmodellen, Antworten immer als JSON-Objekt.

Im Gratis-Tarif hat jedes Modell ein eigenes Kontingent. Ist eins ausgelastet (429),
abgeschaltet (404), gestört (5xx) oder liefert es leeres/kaputtes JSON, kommt das nächste.
An Groq geht nur Text – keine Gerätekennung (Grundbaustein 10).
"""

from __future__ import annotations

import asyncio
import json
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
# Nur für den Katalog-Bau in der GitHub Action: eigenes Gratis-Kontingent, Schlüssel ist das
# GITHUB_TOKEN der Action. Modelle dort heißen in der Kette „github:<modell>“.
GITHUB_MODELS_URL = "https://models.github.ai/inference/chat/completions"
GITHUB_PRAEFIX = "github:"
NAECHSTES_MODELL_STATUS = {404, 429, 500, 502, 503, 504}
VERSUCHE_PRO_MODELL = 2
TIMEOUT_SEKUNDEN = 30.0
# Obergrenze über die ganze Kette – sonst wartet die App bei Störungen mehrere Minuten.
GESAMT_ZEITLIMIT = 45.0


class KiUeberlastet(RuntimeError):
    """Kein Modell der Kette hat brauchbar geantwortet."""


def _payload(modell: str, system: str, nutzer: str, max_tokens: int) -> dict:
    payload = {
        "model": modell.removeprefix(GITHUB_PRAEFIX),
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": nutzer},
        ],
        "temperature": 0.5,
        "max_tokens": max_tokens,
        "response_format": {"type": "json_object"},
    }
    if modell.startswith(GITHUB_PRAEFIX):
        return payload
    if modell.startswith("openai/gpt-oss"):
        payload["reasoning_effort"] = "low"
    else:
        payload["reasoning_format"] = "hidden"
    return payload


def _json_aus(antwort: httpx.Response) -> dict | None:
    try:
        inhalt = antwort.json()["choices"][0]["message"]["content"] or ""
        wert = json.loads(inhalt)
    except (ValueError, KeyError, IndexError, TypeError):
        return None
    return wert if isinstance(wert, dict) else None


async def frage_json(system: str, nutzer: str, *, client: httpx.AsyncClient | None = None,
                     max_tokens: int = 1500, modelle: list[str] | None = None,
                     zeitlimit: float | None = None) -> dict:
    """modelle: eigene Kette statt settings.ki_modelle (der Katalog-Bau fragt je Arbeiter ein Modell)."""
    grenze = zeitlimit or GESAMT_ZEITLIMIT
    try:
        async with asyncio.timeout(grenze):
            return await _kette(system, nutzer, client, max_tokens, modelle or settings.ki_modelle)
    except TimeoutError:
        logger.warning("Groq: Gesamt-Zeitlimit von %s s überschritten", grenze)
        raise KiUeberlastet("Zeitlimit") from None


def _ziel(modell: str) -> tuple[str, str]:
    if modell.startswith(GITHUB_PRAEFIX):
        return GITHUB_MODELS_URL, settings.github_models_token
    return GROQ_URL, settings.groq_api_key


async def _kette(system: str, nutzer: str, client: httpx.AsyncClient | None, max_tokens: int,
                 modelle: list[str]) -> dict:
    eigener_client = client is None
    client = client or httpx.AsyncClient(timeout=TIMEOUT_SEKUNDEN)
    try:
        for modell in modelle:
            url, schluessel = _ziel(modell)
            for _ in range(VERSUCHE_PRO_MODELL):
                try:
                    antwort = await client.post(
                        url,
                        json=_payload(modell, system, nutzer, max_tokens),
                        headers={"Authorization": f"Bearer {schluessel}"},
                    )
                except httpx.HTTPError as fehler:
                    logger.warning("Groq %s nicht erreichbar: %s", modell, fehler)
                    break
                if antwort.status_code in NAECHSTES_MODELL_STATUS:
                    logger.warning("Groq %s: Status %s", modell, antwort.status_code)
                    break
                if antwort.status_code != 200:
                    logger.warning("Groq %s: unerwarteter Status %s %s", modell, antwort.status_code,
                                   antwort.text[:200])
                    break
                wert = _json_aus(antwort)
                if wert is not None:
                    return wert
                logger.warning("Groq %s: leeres oder kaputtes JSON", modell)
        raise KiUeberlastet("Kein Modell hat geantwortet")
    finally:
        if eigener_client:
            await client.aclose()
