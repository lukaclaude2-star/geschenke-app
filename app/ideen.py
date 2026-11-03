"""Amazon-Ideenkarten als Notlösung, wenn passende Feed-Produkte knapp werden.

Die KI nennt Geschenkideen; daraus werden Amazon-Suchlinks. Ausschlüsse und Budget
gelten auch hier (Grundbaustein 3), und jede Karte ist als „Idee“ gekennzeichnet (Grundbaustein 1).
"""

import json
from urllib.parse import quote_plus

from app.bilder import beispielbild
from app.config import settings
from app.ki import KiUeberlastet, frage_json
from app.modelle import Karte, KatalogProdukt, Profil
from app.ranking import ist_ausgeschlossen
from app.vokabular import EIGENSCHAFTEN, FARBEN, LEBENSLAGEN, THEMEN, vokabular_text

SYSTEM = f"""Du schlägst in einer Geschenke-App konkrete, kaufbare Geschenkideen vor, die man
bei Amazon findet. Antworte nur mit JSON:
{{"ideen": [{{"titel": "...", "emoji": "ein Emoji", "preis_von": Zahl, "preis_bis": Zahl,
            "suchbegriff": "2–4 Wörter für die Amazon-Suche", "themen": [...],
            "lebenslagen": [...], "farben": [...], "eigenschaften": [...]}}]}}
Regeln: passend zu den Wünschen; die Wünsche in "schwerpunkt" haben im Shop kaum Produkte –
zu jedem davon mindestens eine Idee, und mindestens die Hälfte der Ideen dazu;
NIE etwas, das einen Ausschluss trifft; Preisspanne innerhalb
von budget_min bis budget_max (null = keine Grenze); keine Ideen aus der Liste "schon_gezeigt".
themen nur aus (eine Zeile je Bereich, genau so geschrieben):
{vokabular_text()}
lebenslagen nur aus: {", ".join(LEBENSLAGEN)}
farben (Hauptfarben, falls festgelegt) nur aus: {", ".join(FARBEN)}
eigenschaften (alles, was jemand ausschließen könnte) nur aus: {", ".join(EIGENSCHAFTEN)}"""


def _link(suchbegriff: str) -> str:
    link = f"https://www.amazon.de/s?k={quote_plus(suchbegriff)}"
    if settings.amazon_tag:
        link += f"&tag={quote_plus(settings.amazon_tag)}"
    return link


def _zahl(wert) -> float | None:
    if isinstance(wert, bool) or not isinstance(wert, (int, float)) or wert <= 0:
        return None
    return float(wert)


def _nur(werte, erlaubt) -> list[str]:
    if not isinstance(werte, list):
        return []
    return [w for w in werte if isinstance(w, str) and w in erlaubt]


def spanne_im_budget(von: float | None, bis: float | None, profil: Profil) -> bool:
    """Ideen haben nur eine Preisspanne: sie muss sich mit dem Budget überschneiden."""
    if profil.budget_min is None and profil.budget_max is None:
        return True
    if von is None and bis is None:
        return False
    von = von if von is not None else bis
    bis = bis if bis is not None else von
    if profil.budget_max is not None and von > profil.budget_max:
        return False
    return profil.budget_min is None or bis >= profil.budget_min


async def ideen_karten(profil: Profil, anzahl: int, gesehen: set[str],
                       schwerpunkt: list[str] | None = None) -> list[Karte]:
    anfrage = {
        "wuensche": [{"tag": w.tag, "gewicht": w.gewicht} for w in profil.wuensche],
        "ausschluesse": [a.schluessel for a in profil.ausschluesse],
        "budget_min": profil.budget_min,
        "budget_max": profil.budget_max,
        "anzahl": anzahl,
        "schwerpunkt": schwerpunkt or [],
        "schon_gezeigt": sorted(i.removeprefix("idee:") for i in gesehen if i.startswith("idee:")),
    }
    try:
        antwort = await frage_json(SYSTEM, json.dumps(anfrage, ensure_ascii=False), max_tokens=1500)
    except KiUeberlastet:
        return []

    ideen = antwort.get("ideen")
    if not isinstance(ideen, list):
        return []
    karten: list[Karte] = []
    for idee in ideen:
        if not isinstance(idee, dict):
            continue
        titel = idee.get("titel")
        suchbegriff = idee.get("suchbegriff")
        if not isinstance(titel, str) or not isinstance(suchbegriff, str):
            continue
        titel, suchbegriff = titel.strip(), suchbegriff.strip()
        if not titel or not suchbegriff:
            continue
        karten_id = "idee:" + suchbegriff.lower()
        if karten_id in gesehen or karten_id in [k.id for k in karten]:
            continue
        themen = _nur(idee.get("themen"), THEMEN)
        preis_von, preis_bis = _zahl(idee.get("preis_von")), _zahl(idee.get("preis_bis"))
        if not spanne_im_budget(preis_von, preis_bis, profil):
            continue
        pruefling = KatalogProdukt(
            id=karten_id, titel=f"{titel} {suchbegriff}", beschreibung="", preis=preis_bis or 0,
            bild_url=None, link="", shop="Amazon", themen=themen,
            lebenslagen=_nur(idee.get("lebenslagen"), LEBENSLAGEN),
            farben=_nur(idee.get("farben"), FARBEN),
            eigenschaften=_nur(idee.get("eigenschaften"), EIGENSCHAFTEN),
            persoenlich=False, note=10, inhalts_hash="",
        )
        if ist_ausgeschlossen(pruefling, profil.ausschluesse):
            continue
        emoji = idee.get("emoji")
        bild = beispielbild(themen)
        karten.append(Karte(
            id=karten_id, art="idee", titel=titel, preis=None, preis_von=preis_von,
            preis_bis=preis_bis, bild_url=bild, beispielbild=bild is not None,
            emoji=emoji[:4] if isinstance(emoji, str) and emoji.strip() else "🎁",
            shop="Amazon", link=_link(suchbegriff), tags=themen,
        ))
        if len(karten) >= anzahl:
            break
    return karten
