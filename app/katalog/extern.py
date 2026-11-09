"""Zusätzliche Gratis-Verschlagworter für den Katalog (OpenAI-kompatible Schnittstellen).

Nur Produktdaten aus Shops gehen hierher, nie Gesprächstext (Grundbaustein 10): Gratis-Anbieter
dürfen mit Eingaben trainieren. Chat, Profil und Ideen bleiben bei Groq (app/ki.py).
Ein weiterer Anbieter ist eine Zeile in ANBIETER plus ein Schlüssel in config.py.
"""

from __future__ import annotations

import asyncio
import json
import logging

import httpx

from app.config import settings
from app.ki import KiUeberlastet

logger = logging.getLogger(__name__)

# anbieter: (Adresse, Name des Schlüssels in settings)
ANBIETER: dict[str, tuple[str, str]] = {
    "nvidia": ("https://integrate.api.nvidia.com/v1/chat/completions", "nvidia_api_key"),
}
VERSUCHE = 2


def _json_aus(antwort: httpx.Response) -> dict | None:
    try:
        wert = json.loads(antwort.json()["choices"][0]["message"]["content"] or "")
    except (ValueError, KeyError, IndexError, TypeError):
        return None
    return wert if isinstance(wert, dict) else None


async def frage_json_extern(system: str, nutzer: str, *, anbieter: str, modell: str,
                            max_tokens: int = 4000, zeitlimit: float = 240) -> dict:
    """Wirft KiUeberlastet bei Kontingent (429), Störung, Netzfehler oder zweimal kaputtem JSON.

    zeitlimit 240: NVIDIA braucht für einen 20er-Stapel gemessen 90–110 Sekunden."""
    adresse, schluessel = ANBIETER[anbieter]
    payload = {
        "model": modell,
        "messages": [{"role": "system", "content": system}, {"role": "user", "content": nutzer}],
        "temperature": 0.3,
        "max_tokens": max_tokens,
        "response_format": {"type": "json_object"},
    }
    kopf = {"Authorization": f"Bearer {getattr(settings, schluessel)}"}
    try:
        async with asyncio.timeout(zeitlimit), httpx.AsyncClient(timeout=zeitlimit) as client:
            for _ in range(VERSUCHE):
                antwort = await client.post(adresse, json=payload, headers=kopf)
                if antwort.status_code != 200:
                    logger.warning("%s %s: Status %s", anbieter, modell, antwort.status_code)
                    raise KiUeberlastet(f"{anbieter} Status {antwort.status_code}")
                wert = _json_aus(antwort)
                if wert is not None:
                    return wert
                logger.warning("%s %s: leeres oder kaputtes JSON (%s Zeichen)", anbieter, modell, len(antwort.text))
    except (TimeoutError, httpx.HTTPError) as fehler:
        logger.warning("%s %s nicht erreichbar: %s", anbieter, modell, type(fehler).__name__)
        raise KiUeberlastet(f"{anbieter} nicht erreichbar") from None
    raise KiUeberlastet(f"{anbieter}: kein brauchbares JSON")
