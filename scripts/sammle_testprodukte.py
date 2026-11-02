"""Sammelt echte Testprodukte aus Shop-Seiten (schema.org-Daten), solange Partner-Feeds fehlen.

Aufruf: python scripts/sammle_testprodukte.py > katalog/quellen/gesammelt.json
Nur für die erste Testversion: später ersetzen die Awin-Feeds dieses Skript.
"""

import html
import json
import random
import re
import sys
import time
from urllib.parse import urljoin

import httpx

KOPF = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130 Safari/537.36",
    "Accept-Language": "de-DE",
}

# shop, Startseite, Muster für Kategorie-Links, Muster für Produkt-Links, Produkte je Shop
SHOPS = [
    ("Jochen Schweizer", "https://www.jochen-schweizer.de/", r'href="(/[a-z0-9\-/]+/l/[a-z0-9]+)"',
     r'href="(/[a-z0-9\-/]+/p/[a-z0-9]+)"', 45),
    ("mydays", "https://www.mydays.de/", r'href="(/[a-z0-9\-/]+/l/[a-z0-9]+)"',
     r'href="(/[a-z0-9\-/]+/p/[a-z0-9]+)"', 45),
    ("Manufactum", "https://www.manufactum.de/", r'href="(/[a-z0-9\-]+-c\d+/)"',
     r'href="(/[a-z0-9\-]+-a\d+/)"', 60),
]
PRODUKTE_JE_KATEGORIE = 4


def hole(client: httpx.Client, url: str) -> str:
    time.sleep(0.4)
    r = client.get(url)
    r.raise_for_status()
    return r.text


def ld_objekte(text: str) -> list[dict]:
    objekte: list[dict] = []
    for roh in re.findall(r'<script[^>]*application/ld\+json[^>]*>(.*?)</script>', text, re.S):
        try:
            daten = json.loads(roh)
        except ValueError:
            continue
        kandidaten = daten if isinstance(daten, list) else daten.get("@graph", [daten]) if isinstance(daten, dict) else []
        objekte.extend(k for k in kandidaten if isinstance(k, dict))
    return objekte


def meta(text: str, name: str) -> str | None:
    m = re.search(rf'<meta[^>]+(?:property|name)="{name}"[^>]+content="([^"]+)"', text)
    return html.unescape(m.group(1)) if m else None


def preis_aus(angebot) -> float | None:
    if isinstance(angebot, list):
        angebot = angebot[0] if angebot else None
    if not isinstance(angebot, dict):
        return None
    for feld in ("price", "lowPrice"):
        try:
            return float(str(angebot.get(feld)).replace(",", "."))
        except (TypeError, ValueError):
            continue
    return None


def produkt_aus(text: str, url: str, shop: str, kategorie: str) -> dict | None:
    produkt = next((o for o in ld_objekte(text) if o.get("@type") == "Product"), None)
    if produkt is None:
        return None
    bild = produkt.get("image")
    if isinstance(bild, list):
        bild = bild[0] if bild else None
    if isinstance(bild, dict):
        bild = bild.get("url")
    bild = meta(text, "og:image") or bild
    beschreibung = produkt.get("description") or meta(text, "og:description") or meta(text, "description") or ""
    angebot = produkt.get("offers")
    verfuegbar = json.dumps(angebot or {})
    preis = preis_aus(angebot)
    if not preis or not bild:
        return None
    return {
        "id": f"{shop.lower().replace(' ', '-')}-{re.sub(r'[^a-z0-9]+', '-', url.rstrip('/').split('/')[-1].lower())}",
        "titel": html.unescape(str(produkt.get("name", ""))).strip(),
        "beschreibung": re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", str(beschreibung)))).strip(),
        "preis": preis,
        "bild_url": urljoin(url, html.unescape(str(bild))),
        "link": url,
        "shop": shop,
        "kategorie": kategorie,
        "lieferbar": "OutOfStock" not in verfuegbar,
    }


def kategorie_name(pfad: str) -> str:
    teil = [t for t in pfad.strip("/").split("/") if t not in ("l", "p")]
    name = re.sub(r"-c\d+$", "", teil[-2] if len(teil) > 1 and len(teil[-1]) <= 6 else teil[-1])
    return name.replace("-", " ").title()


def sammle_shop(client, shop, start, kat_muster, prod_muster, ziel) -> list[dict]:
    startseite = hole(client, start)
    kategorien = sorted(set(re.findall(kat_muster, startseite)))
    random.Random(42).shuffle(kategorien)
    ergebnis: list[dict] = []
    gesehen: set[str] = set()
    for kat in kategorien:
        if len(ergebnis) >= ziel:
            break
        try:
            seite = hole(client, urljoin(start, kat))
        except httpx.HTTPError:
            continue
        treffer = 0
        for pfad in dict.fromkeys(re.findall(prod_muster, seite)):
            if treffer >= PRODUKTE_JE_KATEGORIE or len(ergebnis) >= ziel:
                break
            url = urljoin(start, pfad)
            if url in gesehen:
                continue
            gesehen.add(url)
            try:
                p = produkt_aus(hole(client, url), url, shop, f"{shop} > {kategorie_name(kat)}")
            except httpx.HTTPError:
                continue
            if p and p["titel"]:
                ergebnis.append(p)
                treffer += 1
                print(f"{shop}: {len(ergebnis)} {p['titel'][:60]}", file=sys.stderr)
    return ergebnis


def main() -> None:
    alle: list[dict] = []
    with httpx.Client(headers=KOPF, follow_redirects=True, timeout=20) as client:
        for shop, start, kat, prod, ziel in SHOPS:
            alle.extend(sammle_shop(client, shop, start, kat, prod, ziel))
    json.dump(alle, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
