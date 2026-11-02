"""Ramsch-Filter Stufe 2: Die KI vergibt Schlagwörter und eine Geschenk-Note.

Nur Schlagwörter aus dem Vokabular überleben – so passen Katalog und Profil zusammen.
"""

from __future__ import annotations

import hashlib
import json
import logging

from app.ki import KiUeberlastet, frage_json
from app.modelle import KatalogProdukt, QuellProdukt
from app.vokabular import EIGENSCHAFTEN, FARBEN, LEBENSLAGEN, THEMEN

logger = logging.getLogger(__name__)

STAPELGROESSE = 10

SYSTEM = f"""Du verschlagwortest Produkte für eine Geschenke-App.
Antworte nur mit JSON: {{"produkte": [{{"id": "...", "themen": [...], "lebenslagen": [...],
"farben": [...], "eigenschaften": [...], "persoenlich": true/false, "note": 1-10}}]}}

Erlaubte Werte – nichts anderes verwenden:
- themen: {", ".join(THEMEN)}
- lebenslagen: {", ".join(LEBENSLAGEN)}
- farben: {", ".join(FARBEN)}
- eigenschaften: {", ".join(EIGENSCHAFTEN)}

Regeln:
- themen: 1–4 Interessen, zu denen das Produkt als Geschenk passt. Erlebnisse (Kurse,
  Tickets, Ausflüge) bekommen zusätzlich "erlebnis".
- lebenslagen: nur, wenn das Produkt klar dazu passt (z. B. Einweihung → umzug).
- farben: die sichtbaren Hauptfarben des Produkts.
- eigenschaften: alles, was jemand ausschließen könnte (enthält Alkohol, ist Süßigkeit,
  Lebensmittel, aus Leder, Plastik, duftet, Tierprodukt, braucht Strom/Elektronik).
- persoenlich: true bei Gravur, Personalisierung, Handgemachtem oder Erlebnissen.
- note: "Würde man das guten Gewissens verschenken?" 1 = Ramsch, 10 = tolles Geschenk.
  No-Name-Massenware mit vollgestopften Titeln ("2er Pack Universal Halter NEU") ≤ 3.
Gib jedes Produkt genau einmal zurück, mit derselben id."""


def inhalts_hash(p: QuellProdukt) -> str:
    teile = [p.titel, p.beschreibung, f"{p.preis:.2f}", p.kategorie, p.farbe or ""]
    return hashlib.sha256("\x1f".join(teile).encode("utf-8")).hexdigest()


def _normalisiere_farbe(farbe: str) -> str:
    return farbe.strip().lower().replace("ß", "ss").replace("ü", "ue").replace("ä", "ae").replace("ö", "oe")


def _nur(werte, erlaubt) -> list[str]:
    if not isinstance(werte, list):
        return []
    ergebnis: list[str] = []
    for w in werte:
        if isinstance(w, str) and w in erlaubt and w not in ergebnis:
            ergebnis.append(w)
    return ergebnis


def _note(wert) -> int:
    try:
        return max(1, min(10, int(wert)))
    except (TypeError, ValueError):
        return 1


def _fuer_ki(p: QuellProdukt) -> dict:
    return {"id": p.id, "titel": p.titel, "beschreibung": p.beschreibung[:600],
            "preis": p.preis, "kategorie": p.kategorie, "shop": p.shop}


async def _stapel(ps: list[QuellProdukt]) -> list[KatalogProdukt]:
    try:
        antwort = await frage_json(SYSTEM, json.dumps({"produkte": [_fuer_ki(p) for p in ps]},
                                                      ensure_ascii=False), max_tokens=4000)
    except KiUeberlastet:
        logger.warning("KI überlastet – %d Produkte beim nächsten Lauf", len(ps))
        return []
    eintraege = antwort.get("produkte")
    nach_id = {e.get("id"): e for e in eintraege if isinstance(e, dict)} if isinstance(eintraege, list) else {}
    ergebnis: list[KatalogProdukt] = []
    for p in ps:
        e = nach_id.get(p.id)
        if e is None:
            continue
        farben = _nur(e.get("farben"), FARBEN)
        if p.farbe:
            feed_farbe = _normalisiere_farbe(p.farbe)
            if feed_farbe in FARBEN and feed_farbe not in farben:
                farben.insert(0, feed_farbe)
        ergebnis.append(KatalogProdukt(
            **p.model_dump(),
            themen=_nur(e.get("themen"), THEMEN),
            lebenslagen=_nur(e.get("lebenslagen"), LEBENSLAGEN),
            farben=farben,
            eigenschaften=_nur(e.get("eigenschaften"), EIGENSCHAFTEN),
            persoenlich=e.get("persoenlich") is True,
            note=_note(e.get("note")),
            inhalts_hash=inhalts_hash(p),
        ))
    return ergebnis


async def verschlagworte(ps: list[QuellProdukt]) -> list[KatalogProdukt]:
    ergebnis: list[KatalogProdukt] = []
    for start in range(0, len(ps), STAPELGROESSE):
        ergebnis.extend(await _stapel(ps[start:start + STAPELGROESSE]))
    return ergebnis
