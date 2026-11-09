"""Ramsch-Filter Stufe 2: Die KI vergibt Schlagwörter und eine Geschenk-Note.

Nur Schlagwörter aus dem Vokabular überleben – so passen Katalog und Profil zusammen.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import time

from app.katalog.extern import frage_json_extern
from app.ki import KiUeberlastet, frage_json
from app.modelle import KatalogProdukt, QuellProdukt
from app.vokabular import EIGENSCHAFTEN, FARBEN, LEBENSLAGEN, THEMEN, VOKABULAR_VERSION, vokabular_text

logger = logging.getLogger(__name__)

# Gemessen mit Qwen (03.11.2026): 10 Produkte 4.387 Token, 20 → 6.522. Die Stichwortliste im
# System-Prompt kostet fest ~2.300 Token, größere Stapel teilen sie besser auf. 20 bleibt sicher
# unter Groqs 8.000 Token pro Minute.
STAPELGROESSE = 20
# Ein Arbeiter, dessen Modell überlastet ist, wartet einmal so lange – oft war es nur die
# Minutengrenze. Klappt es danach wieder nicht, ist das Tageskontingent leer.
WARTEN_NACH_UEBERLASTUNG = 65

SYSTEM = f"""Du verschlagwortest Produkte für eine Geschenke-App.
Antworte nur mit JSON: {{"produkte": [{{"id": "...", "themen": [...], "lebenslagen": [...],
"farben": [...], "eigenschaften": [...], "persoenlich": true/false, "note": 1-10}}]}}

Erlaubte Werte – nichts anderes verwenden:
- themen (eine Zeile je Bereich, nimm die genauesten; genau so geschrieben wie hier):
{vokabular_text()}
- lebenslagen: {", ".join(LEBENSLAGEN)}
- farben: {", ".join(FARBEN)}
- eigenschaften: {", ".join(EIGENSCHAFTEN)}

Regeln:
- themen: 1–4 Interessen, zu denen das Produkt als Geschenk passt. Erlebnisse (Kurse,
  Tickets, Ausflüge) bekommen zusätzlich "erlebnis".
- lebenslagen: nur, wenn das Produkt klar dazu passt (z. B. Einweihung → umzug).
- farben: die sichtbaren Hauptfarben eines Gegenstands. Bei Erlebnissen, Kursen,
  Gutscheinen und Reisen IMMER leer.
- eigenschaften: alles, was jemand ausschließen könnte (enthält Alkohol, ist Süßigkeit,
  Lebensmittel, aus Leder, Plastik, duftet, Tierprodukt, braucht Strom/Elektronik).
- persoenlich: true bei Gravur, Personalisierung, Handgemachtem oder Erlebnissen.
- note: "Würde man das guten Gewissens verschenken?" 1 = Ramsch, 10 = tolles Geschenk.
  No-Name-Massenware mit vollgestopften Titeln ("2er Pack Universal Halter NEU") ≤ 3.
Gib jedes Produkt genau einmal zurück, mit derselben id."""


def inhalts_hash(p: QuellProdukt) -> str:
    teile = [p.titel, p.beschreibung, f"{p.preis:.2f}", p.kategorie, p.farbe or "",
             f"vokabular-{VOKABULAR_VERSION}"]
    return hashlib.sha256("\x1f".join(teile).encode("utf-8")).hexdigest()


def _normalisiere_farbe(farbe: str) -> str:
    return farbe.strip().lower().replace("ß", "ss").replace("ü", "ue").replace("ä", "ae").replace("ö", "oe")


def _schluessel(wert: str) -> str:
    """„Einhörner“ → einhoerner, „Craft Beer“ → craft_beer: Die Modelle schreiben Stichwörter
    manchmal mit Umlaut oder Leerzeichen, gemeint ist trotzdem das Wort aus der Liste."""
    return _normalisiere_farbe(wert).replace(" ", "_").replace("-", "_")


def _nur(werte, erlaubt) -> list[str]:
    if not isinstance(werte, list):
        return []
    ergebnis: list[str] = []
    for w in werte:
        if not isinstance(w, str):
            continue
        w = _schluessel(w)
        if w in erlaubt and w not in ergebnis:
            ergebnis.append(w)
    return ergebnis


def _note(wert) -> int:
    try:
        return max(1, min(10, int(wert)))
    except (TypeError, ValueError):
        return 1


def _fuer_ki(p: QuellProdukt) -> dict:
    return {"id": p.id, "titel": p.titel, "beschreibung": p.beschreibung[:300],
            "preis": p.preis, "kategorie": p.kategorie, "shop": p.shop}


def _hat_note(e: dict) -> bool:
    try:
        int(e.get("note"))
    except (TypeError, ValueError):
        return False
    return True


async def _stapel(ps: list[QuellProdukt], modell: str | None = None) -> list[KatalogProdukt]:
    nutzer = json.dumps({"produkte": [_fuer_ki(p) for p in ps]}, ensure_ascii=False)
    if modell and ":" in modell:  # Arbeiter-Schlüssel „<anbieter>:<modell>#<n>“, Groq-Namen haben keinen Doppelpunkt
        anbieter, rest = modell.split(":", 1)
        antwort = await frage_json_extern(SYSTEM, nutzer, anbieter=anbieter, modell=rest.split("#")[0])
    else:
        antwort = await frage_json(SYSTEM, nutzer, max_tokens=4000,
                                   modelle=[modell] if modell else None, zeitlimit=120)
    eintraege = antwort.get("produkte")
    nach_id: dict[str, dict] = {}
    if isinstance(eintraege, list):
        for e in eintraege:
            if isinstance(e, dict) and isinstance(e.get("id"), str):
                nach_id.setdefault(e["id"], e)
    ergebnis: list[KatalogProdukt] = []
    for p in ps:
        e = nach_id.get(p.id)
        # Ohne Note bliebe nur die 1 – das Produkt wäre für immer als Ramsch gespeichert. Qwen lässt
        # die Note bei langen Stapeln manchmal weg; dann lieber beim nächsten Lauf neu fragen.
        if e is None or not _hat_note(e):
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


async def verschlagworte(ps: list[QuellProdukt], pause_sekunden: float = 0,
                         max_stapel: int | None = None,
                         arbeiter: dict[str, float] | None = None,
                         frist_sekunden: float | None = None) -> list[KatalogProdukt]:
    """pause_sekunden zwischen Stapeln: Groq erlaubt im Gratis-Tarif nur ~8.000 Token pro Minute.

    max_stapel begrenzt einen Lauf, und nach der ersten Überlastung ist Schluss – sonst verbraucht
    der Katalog das Tageskontingent, das die App für Chat und Ideen braucht. Der Rest kommt beim
    nächsten Lauf dran.

    arbeiter {modell: pause}: Jedes Modell hat ein eigenes Kontingent. Dann fragen alle Modelle
    gleichzeitig, jedes mit eigener Pause, und holen sich die Stapel aus einer gemeinsamen Schlange.

    frist_sekunden: Danach nimmt kein Arbeiter mehr einen neuen Stapel. GitHub bricht einen zu
    langen Lauf sonst ab, bevor katalog.json gespeichert ist – und alles wäre verloren."""
    stapel = [ps[i:i + STAPELGROESSE] for i in range(0, len(ps), STAPELGROESSE)]
    if max_stapel is not None and len(stapel) > max_stapel:
        logger.warning("Stapelgrenze erreicht – %d Produkte beim nächsten Lauf",
                       sum(len(s) for s in stapel[max_stapel:]))
        stapel = stapel[:max_stapel]
    if arbeiter:
        return await _parallel(stapel, arbeiter, frist_sekunden)
    ergebnis: list[KatalogProdukt] = []
    for nummer, teil in enumerate(stapel):
        if nummer and pause_sekunden:
            await asyncio.sleep(pause_sekunden)
        try:
            ergebnis.extend(await _stapel(teil))
        except KiUeberlastet:
            logger.warning("KI überlastet – %d Produkte beim nächsten Lauf",
                           sum(len(s) for s in stapel[nummer:]))
            break
    return ergebnis


async def _parallel(stapel: list[list[QuellProdukt]], arbeiter: dict[str, float],
                    frist_sekunden: float | None = None) -> list[KatalogProdukt]:
    ende = None if frist_sekunden is None else time.monotonic() + frist_sekunden
    schlange: asyncio.Queue[list[QuellProdukt]] = asyncio.Queue()
    for teil in stapel:
        schlange.put_nowait(teil)
    ergebnis: list[KatalogProdukt] = []

    async def arbeite(modell: str, pause: float) -> None:
        geschafft, erster = 0, True
        while not schlange.empty():
            if not erster and pause:
                await asyncio.sleep(pause)
            if ende is not None and time.monotonic() >= ende or schlange.empty():
                break
            teil = schlange.get_nowait()
            erster = False
            try:
                fertig = await _stapel(teil, modell)
            except KiUeberlastet:
                await asyncio.sleep(WARTEN_NACH_UEBERLASTUNG)
                try:
                    fertig = await _stapel(teil, modell)
                except KiUeberlastet:
                    schlange.put_nowait(teil)  # ein anderes Modell kann ihn noch übernehmen
                    break
            if not geschafft:  # Stichprobe im Log, damit man die Modelle vergleichen kann
                for p in fertig[:3]:
                    logger.warning("  %s: %s → %s, Note %d", modell, p.titel[:50], p.themen, p.note)
            ergebnis.extend(fertig)
            geschafft += len(fertig)
        logger.warning("Katalog: %s hat %d Produkte verschlagwortet", modell, geschafft)

    await asyncio.gather(*(arbeite(m, p) for m, p in arbeiter.items()))
    if not schlange.empty():
        logger.warning("Frist erreicht oder alle Modelle überlastet – %d Stapel beim nächsten Lauf", schlange.qsize())
    return ergebnis
