"""Liest Awin-Produktfeeds (CSV) als Quellprodukte.

Awin liefert je nach Feed-Art andere Spaltennamen: Legacy-Download für Publisher (aw_deep_link,
search_price, merchant_image_url …), Händler-Format (deep_link, price, image_url …) und Enhanced
im Google-Format (aw_deep_link, title, price, image_link, availability …). Deshalb gibt es je Feld
mehrere Kandidaten; der erste gefüllte gewinnt.
"""

from __future__ import annotations

import csv
import gzip
import io
import re
import zipfile

from app.katalog.jsonld import _zahl
from app.modelle import QuellProdukt

LINK = ("aw_deep_link", "deep_link", "merchant_deep_link", "link")
ID = ("aw_product_id", "product_id", "id", "merchant_product_id")
TITEL = ("product_name", "title")
BESCHREIBUNG = ("description", "product_short_description")
PREIS = ("search_price", "sale_price", "price", "store_price", "display_price")
# Große Händlerbilder zuerst: aw_image_url ist bei Awin oft nur ein kleines Vorschaubild.
BILD = ("large_image", "merchant_image_url", "image_url", "image_link", "aw_image_url")
SHOP = ("merchant_name", "brand_name")
KATEGORIE = ("merchant_category", "category_name", "product_type", "google_product_category")
FARBE = ("colour", "color")
GRUPPE = ("item_group_id", "parent_product_id")
NICHT_LIEFERBAR = re.compile(r"out[_ ]?o[uf]{1,2}[_ ]?stock|ausverkauft|nicht (?:lieferbar|verfügbar)|sold out",
                             re.I)


def feed_text(inhalt: bytes) -> str:
    """Rohdaten (CSV, gzip oder zip) → Text. Awin bietet beim Download alle drei an."""
    if inhalt[:2] == b"\x1f\x8b":
        inhalt = gzip.decompress(inhalt)
    elif inhalt[:2] == b"PK":
        with zipfile.ZipFile(io.BytesIO(inhalt)) as archiv:
            inhalt = archiv.read(archiv.namelist()[0])
    return inhalt.decode("utf-8-sig", errors="replace")


def _feld(zeile: dict[str, str], namen: tuple[str, ...]) -> str:
    for name in namen:
        wert = (zeile.get(name) or "").strip()
        if wert:
            return wert
    return ""


def _lieferbar(zeile: dict[str, str]) -> bool:
    if (zeile.get("in_stock") or "").strip() == "0":
        return False
    zustand = " ".join(zeile.get(s) or "" for s in ("availability", "stock_status"))
    return not NICHT_LIEFERBAR.search(zustand)


def produkt_aus_zeile(zeile: dict[str, str], shop: str = "") -> QuellProdukt | None:
    """Eine Feed-Zeile → Quellprodukt, oder None, wenn Pflichtangaben fehlen."""
    zeile = {(k or "").strip().lower(): v for k, v in zeile.items()}
    link, titel, roh_id = _feld(zeile, LINK), _feld(zeile, TITEL), _feld(zeile, ID)
    preis = _zahl(_feld(zeile, PREIS))
    waehrung = (zeile.get("currency") or "").strip().upper()
    if not (link and titel and roh_id and preis) or waehrung not in ("", "EUR"):
        return None
    if not link.startswith("https://"):
        return None
    return QuellProdukt(
        id=f"awin-{re.sub(r'[^A-Za-z0-9_-]+', '-', roh_id)}",
        titel=titel,
        beschreibung=_feld(zeile, BESCHREIBUNG),
        preis=preis,
        bild_url=_feld(zeile, BILD) or None,
        link=link,
        shop=shop or _feld(zeile, SHOP) or "Shop",
        kategorie=_feld(zeile, KATEGORIE),
        lieferbar=_lieferbar(zeile),
        farbe=_feld(zeile, FARBE) or None,
        varianten_gruppe=_feld(zeile, GRUPPE) or None,
    )


def produkte_aus_feed(text: str, shop: str = "") -> list[QuellProdukt]:
    """Ganzer Feed → Quellprodukte (doppelte IDs nur einmal). Trennzeichen wird erkannt."""
    kopf = text.split("\n", 1)[0]
    trenner = max(",;|\t", key=kopf.count)
    produkte: dict[str, QuellProdukt] = {}
    for zeile in csv.DictReader(io.StringIO(text), delimiter=trenner):
        p = produkt_aus_zeile(zeile, shop)
        if p is not None and p.id not in produkte:
            produkte[p.id] = p
    return list(produkte.values())
