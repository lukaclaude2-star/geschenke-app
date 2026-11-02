"""Produktdaten aus Shop-Seiten lesen (schema.org/JSON-LD) – funktioniert für fast jedes
Shopsystem (Shopware, WooCommerce, Magento, …), weil Shops diese Daten für Google einbauen.

Shopify-Shops werden erkannt und abgelehnt (Lukas Vorgabe für Runde 3).
"""

from __future__ import annotations

import hashlib
import html
import json
import re
import xml.etree.ElementTree as ET
from urllib.parse import urljoin

from app.modelle import QuellProdukt

_LD_SKRIPT = re.compile(r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>', re.S | re.I)


def _slug(text: str) -> str:
    text = text.lower()
    for umlaut, ersatz in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        text = text.replace(umlaut, ersatz)
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def _objekte(wert) -> list[dict]:
    """Alle Objekte aus einem JSON-LD-Block – auch in Listen und @graph."""
    if isinstance(wert, list):
        return [o for w in wert for o in _objekte(w)]
    if not isinstance(wert, dict):
        return []
    return [wert] + _objekte(wert.get("@graph", []))


def _ist_produkt(o: dict) -> bool:
    typ = o.get("@type")
    typen = typ if isinstance(typ, list) else [typ]
    return any(isinstance(t, str) and t.split("/")[-1] in ("Product", "ProductGroup") for t in typen)


def _zahl(wert) -> float | None:
    if isinstance(wert, bool) or wert is None:
        return None
    if isinstance(wert, (int, float)):
        return float(wert) if wert > 0 else None
    text = re.sub(r"[^\d,.]", "", str(wert))
    if not text:
        return None
    if "," in text and "." in text:
        text = text.replace(".", "").replace(",", ".") if text.rfind(",") > text.rfind(".") else text.replace(",", "")
    elif re.fullmatch(r"\d{1,3}(\.\d{3})+", text):
        text = text.replace(".", "")  # deutscher Tausenderpunkt ohne Cent: „12.500“
    else:
        text = text.replace(",", ".")
    try:
        zahl = float(text)
    except ValueError:
        return None
    return zahl if zahl > 0 else None


def _preis(angebote) -> float | None:
    if isinstance(angebote, list):
        preise = [p for p in (_preis(a) for a in angebote) if p is not None]
        return min(preise) if preise else None
    if not isinstance(angebote, dict):
        return None
    for feld in ("price", "lowPrice"):
        zahl = _zahl(angebote.get(feld))
        if zahl is not None:
            return zahl
    spezifikation = angebote.get("priceSpecification")
    if spezifikation is not None:
        return _preis(spezifikation)
    return None


def _bild(wert, url: str) -> str | None:
    if isinstance(wert, list):
        wert = wert[0] if wert else None
    if isinstance(wert, dict):
        wert = wert.get("url") or wert.get("contentUrl")
    if not isinstance(wert, str) or not wert.strip():
        return None
    return urljoin(url, html.unescape(wert.strip()))


def _meta(text: str, name: str) -> str | None:
    treffer = re.search(r'<meta[^>]+(?:property|name)=["\']' + re.escape(name) + r'["\'][^>]+content=["\']([^"\']+)',
                        text, re.I)
    return html.unescape(treffer.group(1)) if treffer else None


def _text(wert) -> str:
    text = html.unescape(re.sub(r"<[^>]+>", " ", str(wert or "")))
    return re.sub(r"\s+", " ", text).strip()


def produkte_aus_html(text: str, url: str, shop: str) -> list[QuellProdukt]:
    objekte: list[dict] = []
    for block in _LD_SKRIPT.findall(text):
        try:
            objekte += _objekte(json.loads(block.strip()))
        except (json.JSONDecodeError, ValueError):
            continue
    ergebnis: list[QuellProdukt] = []
    produkte = [o for o in objekte if _ist_produkt(o)]
    if len({_text(o.get("name")) for o in produkte} - {""}) > 1:
        return []  # mehrere verschiedene Produkte → Kategorie- oder Listenseite, keine Produktseite
    for o in produkte:
        angebote = o.get("offers")
        if angebote is None and isinstance(o.get("hasVariant"), list) and o["hasVariant"]:
            angebote = o["hasVariant"][0].get("offers") if isinstance(o["hasVariant"][0], dict) else None
        preis = _preis(angebote)
        bild = _bild(o.get("image"), url) or _bild(_meta(text, "og:image"), url)
        titel = _text(o.get("name"))
        if preis is None or bild is None or not titel:
            continue
        beschreibung = _text(o.get("description")) or _text(_meta(text, "og:description"))
        kategorie = o.get("category")
        ergebnis.append(QuellProdukt(
            id=f"{_slug(shop)}-{hashlib.sha1(url.encode()).hexdigest()[:10]}",
            titel=titel,
            beschreibung=beschreibung,
            preis=round(preis, 2),
            bild_url=bild,
            link=url,
            shop=shop,
            kategorie=f"{shop} > {_text(kategorie)}" if isinstance(kategorie, str) and kategorie.strip() else shop,
            lieferbar="OutOfStock" not in json.dumps(angebote or {}) and "SoldOut" not in json.dumps(angebote or {}),
        ))
        break  # eine Seite = ein Produkt; weitere Einträge sind meist Zubehör oder Varianten
    if not ergebnis:
        ersatz = _aus_microdata(text, url, shop)
        if ersatz is not None:
            ergebnis.append(ersatz)
    return ergebnis


def _itemprop(text: str, name: str) -> str | None:
    """content="…" eines itemprop – die Form, die Shopware und Co. für Preise nutzen."""
    for muster in (r"""itemprop=["']""" + name + r"""["'][^>]*content=["']([^"']+)""",
                   r"""content=["']([^"']+)["'][^>]*itemprop=["']""" + name + r"""["']"""):
        treffer = re.search(muster, text, re.I)
        if treffer:
            return html.unescape(treffer.group(1))
    return None


def _einziger_preis(text: str) -> str | None:
    """itemprop="price" nur, wenn die Seite genau einen Preis nennt – sonst gehört er evtl. zu Zubehör."""
    werte = set(re.findall(r"""itemprop=["']price["'][^>]*content=["']([^"']+)""", text, re.I))
    werte |= set(re.findall(r"""content=["']([^"']+)["'][^>]*itemprop=["']price["']""", text, re.I))
    return html.unescape(werte.pop()) if len(werte) == 1 else None


def _aus_microdata(text: str, url: str, shop: str) -> QuellProdukt | None:
    """Ersatz für Shops ohne JSON-LD: schema.org-Microdata plus Open-Graph-Angaben.
    Nur Seiten, die sich selbst als Produkt auszeichnen – sonst wären Kategorieseiten dabei."""
    kaesten = len(re.findall(r"""itemtype=["']https?://schema\.org/Product["']""", text, re.I))
    if kaesten > 1:
        return None  # Produktkästen einer Kategorieseite
    if kaesten == 0 and (_meta(text, "og:type") or "").lower() != "product":
        return None
    preis = _zahl(_meta(text, "product:price:amount") or _meta(text, "og:price:amount") or _einziger_preis(text))
    # Kein itemprop="name": das erste ist oft die Marke („Tojo“ statt „Schreibtisch Tojo Stand“).
    ueberschrift = re.search(r"<h1[^>]*>(.*?)</h1>", text, re.I | re.S)
    titel = _text(_meta(text, "og:title") or (ueberschrift.group(1) if ueberschrift else ""))
    bild = _bild(_meta(text, "og:image") or _itemprop(text, "image"), url)
    if preis is None or not titel or bild is None:
        return None
    beschreibung = _text(_meta(text, "og:description") or _meta(text, "description") or _itemprop(text, "description"))
    verfuegbar = re.search(r"""itemprop=["']availability["'][^>]*(?:href|content)=["']([^"']+)""", text, re.I)
    return QuellProdukt(
        id=f"{_slug(shop)}-{hashlib.sha1(url.encode()).hexdigest()[:10]}",
        titel=titel, beschreibung=beschreibung, preis=round(preis, 2), bild_url=bild, link=url, shop=shop,
        kategorie=shop,
        lieferbar=not (verfuegbar and re.search(r"OutOfStock|SoldOut", verfuegbar.group(1))),
    )


def ist_shopify(text: str, kopfzeilen) -> bool:
    namen = {k.lower() for k in kopfzeilen}
    if any(n.startswith("x-shopify") or n == "x-shopid" for n in namen):
        return True
    if "shopify" in str(kopfzeilen.get("powered-by", "")).lower():
        return True
    return "cdn.shopify.com" in text or "Shopify.theme" in text or "myshopify.com" in text


def urls_aus_sitemap(xml: str) -> tuple[list[str], list[str]]:
    """(Seiten, Unter-Sitemaps) aus einer Sitemap oder einem Sitemap-Index."""
    try:
        wurzel = ET.fromstring(xml.strip().encode("utf-8"))
    except ET.ParseError:
        return [], []
    locs = [e.text.strip() for e in wurzel.iter() if e.tag.endswith("loc") and e.text and e.text.strip()]
    if wurzel.tag.endswith("sitemapindex"):
        return [], locs
    return locs, []
