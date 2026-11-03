"""Sammelt Produkte aus den Shops in katalog/shops.json (ohne Shopify, robots.txt wird beachtet).

Aufrufe:
  python scripts/sammle_shops.py                 alle Shops → katalog/quellen/shop-<name>.json
  python scripts/sammle_shops.py --nur "A" "B"   nur diese Shops
  python scripts/sammle_shops.py --ziel 50       bis zu 50 Produkte je Shop (Standard 30)
  python scripts/sammle_shops.py --pruefe URL…   nur prüfen: lesbar / Shopify / blockiert

Weg: robots.txt → Sitemaps → Produktseiten als Stichprobe → schema.org-Daten (JSON-LD).
Bis Awin-Feeds da sind, ersetzt das die Partner-Feeds (Testphase, siehe Design-Dokument).
"""

from __future__ import annotations

import argparse
import asyncio
import gzip
import json
import random
import re
import sys
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.robotparser import RobotFileParser

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.katalog.jsonld import _slug, ist_shopify, produkte_aus_html, urls_aus_sitemap  # noqa: E402
from app.katalog.regeln import pruefe_regeln  # noqa: E402

WURZEL = Path(__file__).resolve().parent.parent
KOPF = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130 Safari/537.36",
    "Accept-Language": "de-DE,de;q=0.9",
}
PRODUKTE_JE_SHOP = 30
MAX_SEITEN = 120
AUFGEBEN_NACH = 30  # so viele Seiten ohne ein einziges Produkt → Shop nicht lesbar
MAX_SITEMAPS = 25
PAUSE = 0.5
DATEI = re.compile(r"\.(jpe?g|png|gif|webp|svg|pdf|xml|mp4)$", re.I)
MEDIEN_SITEMAP = re.compile(r"image|bild|video|media", re.I)
# Startadresse ohne Sprachpfad: Deutsch liegt dann meist ohne Präfix, andere Sprachen unter /en/, /fr/ …
FREMDSPRACHE = re.compile(r"/(en|fr|it|es|nl|pl|cs|da|sv|fi|no|pt|hu|ro|sk|sl|hr|el|tr|ru|ja|zh|ko)([-_][a-z]{2})?(/|$)", re.I)
PRODUKT_HINWEIS = re.compile(r"product|produkt|artikel|item|detail", re.I)
KEIN_PRODUKT = re.compile(r"/(blog|magazin|ratgeber|news|hilfe|service|kontakt|impressum|agb|datenschutz|"
                          r"karriere|jobs|filiale|marken?|brands?|kategorie|category|cms|faq|account|"
                          r"login|warenkorb|cart|checkout|search|suche)(/|$)", re.I)


async def hole(client: httpx.AsyncClient, url: str) -> httpx.Response | None:
    await asyncio.sleep(PAUSE)
    try:
        antwort = await client.get(url)
    except (httpx.HTTPError, ValueError):
        return None
    return antwort if antwort.status_code == 200 else None


def seitentext(antwort: httpx.Response) -> str:
    """Manche Shops liefern Latin-1 ohne Angabe im Header – dann nicht als UTF-8 raten."""
    try:
        return antwort.content.decode(antwort.encoding or "utf-8")
    except (UnicodeDecodeError, LookupError):
        pass
    try:
        return antwort.content.decode("utf-8")
    except UnicodeDecodeError:
        return antwort.content.decode("cp1252", errors="replace")


def _sitemap_text(antwort: httpx.Response) -> str:
    inhalt = antwort.content
    if inhalt[:2] == b"\x1f\x8b":
        try:
            inhalt = gzip.decompress(inhalt)
        except OSError:
            return ""
    return inhalt.decode("utf-8", errors="replace")


async def robots(client: httpx.AsyncClient, basis: str) -> tuple[RobotFileParser, list[str]]:
    parser = RobotFileParser()
    antwort = await hole(client, urljoin(basis, "/robots.txt"))
    zeilen = antwort.text.splitlines() if antwort is not None else []
    parser.parse(zeilen)
    sitemaps = [z.split(":", 1)[1].strip() for z in zeilen if z.lower().startswith("sitemap:")]
    return parser, sitemaps


async def seiten_aus_sitemaps(client: httpx.AsyncClient, start: list[str]) -> list[str]:
    offen = list(dict.fromkeys(start))
    gelesen = 0
    seiten: list[str] = []
    while offen and gelesen < MAX_SITEMAPS:
        # Produkt-Sitemaps zuerst, Bild- und Video-Sitemaps zuletzt
        offen.sort(key=lambda u: 2 if MEDIEN_SITEMAP.search(u) else 0 if PRODUKT_HINWEIS.search(u) else 1)
        url = offen.pop(0)
        antwort = await hole(client, url)
        gelesen += 1
        if antwort is None:
            continue
        neue_seiten, unter = urls_aus_sitemap(_sitemap_text(antwort))
        seiten += neue_seiten
        offen += [u for u in unter if u not in offen]
        if len(seiten) > 20000:
            break
    return list(dict.fromkeys(seiten))


def _kandidaten(seiten: list[str], basis: str) -> list[str]:
    host = urlparse(basis).netloc.lower().removeprefix("www.")
    # Startadresse mit Sprachpfad (/de-de/, /de/) → nur Seiten dieser Sprachversion, sonst landen
    # italienische Titel und Links im Katalog.
    sprache = urlparse(basis).path.lower().rstrip("/")
    passend = []
    for u in seiten:
        try:
            teile = urlparse(u)
        except ValueError:
            continue
        pfad = teile.path
        if teile.netloc.lower().removeprefix("www.") != host or not pfad.strip("/"):
            continue
        if sprache and not pfad.lower().startswith(sprache + "/"):
            continue
        if not sprache and FREMDSPRACHE.match(pfad):
            continue
        if KEIN_PRODUKT.search(pfad) or DATEI.search(pfad):
            continue
        passend.append(u)
    random.Random(42).shuffle(passend)
    # Seiten, deren Pfad nach Produkt aussieht, zuerst
    passend.sort(key=lambda u: 0 if PRODUKT_HINWEIS.search(urlparse(u).path) else 1)
    return passend


async def sammle(shop: dict, ziel: int = PRODUKTE_JE_SHOP, max_seiten: int = MAX_SEITEN) -> dict:
    name, basis = shop["name"], shop["url"]
    bericht = {"name": name, "url": basis, "status": "", "produkte": [], "seiten": 0}
    async with httpx.AsyncClient(headers=KOPF, follow_redirects=True, timeout=20) as client:
        start = await hole(client, basis)
        if start is None:
            bericht["status"] = "blockiert (Startseite)"
            return bericht
        if ist_shopify(seitentext(start), start.headers):
            bericht["status"] = "Shopify – abgelehnt"
            return bericht
        regeln, sitemaps = await robots(client, basis)
        sitemaps = shop.get("sitemaps") or sitemaps or [urljoin(basis, "/sitemap.xml"),
                                                       urljoin(basis, "/sitemap_index.xml")]
        # Mehrsprachige Shops: nur die Sitemaps der gewählten Sprachversion, sonst ist die Grenze
        # schon mit fremdsprachigen Seiten voll.
        sprache = urlparse(basis).path.lower().rstrip("/")
        if sprache:
            sitemaps = [s for s in sitemaps if sprache + "/" in s.lower()] or sitemaps
        seiten = await seiten_aus_sitemaps(client, sitemaps)
        kandidaten = [u for u in _kandidaten(seiten, basis) if regeln.can_fetch(KOPF["User-Agent"], u)]
        if not kandidaten:
            bericht["status"] = "keine Sitemap/Seiten"
            return bericht
        produkte: dict[str, dict] = {}
        for url in kandidaten[:max_seiten]:
            if len(produkte) >= ziel:
                break
            if bericht["seiten"] >= AUFGEBEN_NACH and not produkte:
                break
            antwort = await hole(client, url)
            bericht["seiten"] += 1
            if antwort is None:
                continue
            text = seitentext(antwort)
            if ist_shopify(text, antwort.headers):
                bericht["status"] = "Shopify – abgelehnt"
                return bericht
            for p in produkte_aus_html(text, str(antwort.url), name):
                if pruefe_regeln(p) is None and p.id not in produkte:
                    produkte[p.id] = p.model_dump(exclude_none=True)
        bericht["produkte"] = list(produkte.values())
        bericht["status"] = "lesbar" if produkte else "keine Produktdaten"
    return bericht


async def main() -> None:
    argumente = argparse.ArgumentParser()
    argumente.add_argument("--pruefe", nargs="*")
    argumente.add_argument("--nur", nargs="+")
    argumente.add_argument("--ziel", type=int, default=PRODUKTE_JE_SHOP)
    argumente.add_argument("--gleichzeitig", type=int, default=10)
    a = argumente.parse_args()

    if a.pruefe:
        shops = [{"name": urlparse(u).netloc.removeprefix("www."), "url": u} for u in a.pruefe]
        grenze = asyncio.Semaphore(a.gleichzeitig)

        async def pruefe(shop):
            async with grenze:
                b = await sammle(shop, ziel=3, max_seiten=40)
            print(f"{b['status']:<24} {len(b['produkte']):>2} Produkte / {b['seiten']:>3} Seiten  {shop['url']}",
                  flush=True)
        await asyncio.gather(*(pruefe(s) for s in shops))
        return

    shops = json.loads((WURZEL / "katalog" / "shops.json").read_text(encoding="utf-8"))
    if a.nur:
        shops = [s for s in shops if s["name"] in a.nur]
    grenze = asyncio.Semaphore(a.gleichzeitig)
    ordner = WURZEL / "katalog" / "quellen"

    async def lauf(shop):
        async with grenze:
            try:
                # Mehr Produkte brauchen mehr Seiten: viele Produktseiten liefern keine Daten.
                b = await sammle(shop, ziel=a.ziel, max_seiten=max(MAX_SEITEN, a.ziel * 4))
            except Exception as fehler:  # ein kaputter Shop darf die anderen nicht abbrechen
                b = {"status": f"Fehler: {type(fehler).__name__}", "produkte": []}
        if b["produkte"]:
            datei = ordner / f"shop-{_slug(shop['name'])}.json"
            datei.write_text(json.dumps(b["produkte"], ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"{b['status']:<24} {len(b['produkte']):>2} Produkte  {shop['name']}", flush=True)
    await asyncio.gather(*(lauf(s) for s in shops))


if __name__ == "__main__":
    asyncio.run(main())
