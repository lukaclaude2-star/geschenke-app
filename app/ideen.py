"""Amazon-Ideenkarten als Notlösung, wenn passende Feed-Produkte knapp werden.

Die KI nennt Geschenkideen; daraus werden Amazon-Suchlinks. Ausschlüsse und Budget
gelten auch hier (Grundbaustein 3), und jede Karte ist als „Idee“ gekennzeichnet (Grundbaustein 1).
"""

import json
from urllib.parse import quote_plus

from app.config import settings
from app.ki import KiUeberlastet, frage_json
from app.modelle import Karte, KatalogProdukt, Profil
from app.ranking import ist_ausgeschlossen
from app.vokabular import THEMEN

SYSTEM = """Du schlägst in einer Geschenke-App konkrete, kaufbare Geschenkideen vor, die man
bei Amazon findet. Antworte nur mit JSON:
{"ideen": [{"titel": "...", "emoji": "ein Emoji", "preis_von": Zahl, "preis_bis": Zahl,
            "suchbegriff": "2–4 Wörter für die Amazon-Suche", "themen": ["..."]}]}
Regeln: passend zu den Wünschen; NIE etwas, das einen Ausschluss trifft; preis_bis höchstens
das Budget; keine Ideen aus der Liste "schon_gezeigt"; themen nur aus: """ + ", ".join(THEMEN)


def _link(suchbegriff: str) -> str:
    link = f"https://www.amazon.de/s?k={quote_plus(suchbegriff)}"
    if settings.amazon_tag:
        link += f"&tag={quote_plus(settings.amazon_tag)}"
    return link


def _zahl(wert) -> float | None:
    if isinstance(wert, bool) or not isinstance(wert, (int, float)) or wert <= 0:
        return None
    return float(wert)


async def ideen_karten(profil: Profil, anzahl: int, gesehen: set[str]) -> list[Karte]:
    anfrage = {
        "wuensche": [{"tag": w.tag, "gewicht": w.gewicht} for w in profil.wuensche],
        "ausschluesse": [a.schluessel for a in profil.ausschluesse],
        "budget_max": profil.budget_max,
        "anzahl": anzahl,
        "schon_gezeigt": sorted(i.removeprefix("idee:") for i in gesehen if i.startswith("idee:")),
    }
    try:
        antwort = await frage_json(SYSTEM, json.dumps(anfrage, ensure_ascii=False), max_tokens=1500)
    except KiUeberlastet:
        return []

    karten: list[Karte] = []
    for idee in antwort.get("ideen") or []:
        if not isinstance(idee, dict):
            continue
        titel = str(idee.get("titel") or "").strip()
        suchbegriff = str(idee.get("suchbegriff") or "").strip()
        if not titel or not suchbegriff:
            continue
        karten_id = "idee:" + suchbegriff.lower()
        if karten_id in gesehen or karten_id in [k.id for k in karten]:
            continue
        themen = [t for t in idee.get("themen") or [] if t in THEMEN]
        preis_von, preis_bis = _zahl(idee.get("preis_von")), _zahl(idee.get("preis_bis"))
        if profil.budget_max is not None and (preis_bis is None or preis_bis > profil.budget_max):
            continue
        pruefling = KatalogProdukt(
            id=karten_id, titel=f"{titel} {suchbegriff}", beschreibung="", preis=preis_bis or 0,
            bild_url=None, link="", shop="Amazon", themen=themen, lebenslagen=[], farben=[],
            eigenschaften=[], persoenlich=False, note=0, inhalts_hash="",
        )
        if ist_ausgeschlossen(pruefling, profil.ausschluesse):
            continue
        karten.append(Karte(
            id=karten_id, art="idee", titel=titel, preis=None, preis_von=preis_von,
            preis_bis=preis_bis, bild_url=None, emoji=str(idee.get("emoji") or "🎁")[:4],
            shop="Amazon", link=_link(suchbegriff), tags=themen,
        ))
        if len(karten) >= anzahl:
            break
    return karten
