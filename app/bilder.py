"""Beispielbilder für Ideenkarten aus Pexels (kostenlos; Schlüssel nur auf dem Server).

Ideenkarten führen zur Amazon-Suche, echte Amazon-Fotos gibt es erst mit der Produkt-API.
Das Foto zeigt ein passendes Beispiel und wird in der App als „Beispielbild · Pexels“ markiert.
Ohne Schlüssel oder bei Fehlern gibt es kein Bild – die Karte zeigt dann ihr Emoji.
"""

import httpx

from app.config import settings

PEXELS_SUCHE = "https://api.pexels.com/v1/search"
_CACHE: dict[str, str | None] = {}
_CACHE_GROESSE = 2000


def leere_cache() -> None:
    _CACHE.clear()


async def beispielbild(suchbegriff: str) -> str | None:
    if not settings.pexels_key:
        return None
    schluessel = " ".join(suchbegriff.lower().split())
    if schluessel in _CACHE:
        return _CACHE[schluessel]
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            antwort = await client.get(PEXELS_SUCHE, headers={"Authorization": settings.pexels_key},
                                       params={"query": suchbegriff.strip(), "per_page": 1,
                                               "locale": "de-DE", "orientation": "landscape"})
        antwort.raise_for_status()
        fotos = antwort.json().get("photos") or []
        url = fotos[0]["src"]["large"] if fotos else None
    except (httpx.HTTPError, ValueError, KeyError, TypeError, AttributeError):
        return None  # Fehler nicht merken – beim nächsten Mal klappt es vielleicht
    if len(_CACHE) >= _CACHE_GROESSE:
        _CACHE.pop(next(iter(_CACHE)))
    _CACHE[schluessel] = url
    return url
