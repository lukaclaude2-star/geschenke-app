"""Profil aus dem Gespräch ableiten und per Chat ändern.

Die KI liefert Rohdaten; bereinige_profil lässt nur Vokabular durch (Grundbaustein 3/5).
Beim Ändern liefert die KI nur die Änderung – was sie nicht erwähnt, bleibt, wie es war.
So kann ein Ersatzmodell mit dürftiger Antwort keine Ausschlüsse verschwinden lassen.
"""

import json

from app.gespraech import verlauf_text
from app.ki import frage_json
from app.modelle import Ausschluss, ChatNachricht, Profil, Wunsch
from app.vokabular import (EIGENSCHAFTEN, FARBEN, LEBENSLAGEN, THEMEN, ist_gueltiger_ausschluss,
                           label_fuer, tag_label)

REGELN = f"""Erlaubte Wunsch-Tags: {", ".join(list(THEMEN) + list(LEBENSLAGEN))}
Ausschluss-Schlüssel haben die Form "<art>:<wert>":
- "thema:<Wunsch-Tag>"
- "farbe:<{"|".join(FARBEN)}>"
- "eigenschaft:<{"|".join(EIGENSCHAFTEN)}>"
- "wort:<kürzester treffender Wortstamm, klein>" – nur wenn nichts anderes passt
  (Beispiel: „nichts mit Katzen-Motiv“ wird zu wort mit dem Wert katze).
Gewicht: 1.5 = liebt es / ganz wichtig, 1.0 = mag es, 0.5 = nebenbei.
Alles, was die Person nicht mag, nicht darf oder schon hat, wird ein Ausschluss.
Nur aufnehmen, was im Text wirklich steht – nichts dazuerfinden."""

SYSTEM_AUS_GESPRAECH = f"""Du wertest ein Gespräch in einer Geschenke-App aus.
Antworte nur mit JSON in dieser Form:
{{"zusammenfassung": "<ein Satz über die Person>",
  "wuensche": [{{"tag": "<Wunsch-Tag>", "gewicht": <0.5 bis 1.5>}}],
  "ausschluesse": ["<art>:<wert>"],
  "budget_max": <Obergrenze in Euro oder null>}}

{REGELN}
budget_max ist null, wenn das Budget egal ist oder nicht genannt wurde."""

SYSTEM_AENDERN = f"""Du änderst ein gespeichertes Personen-Profil einer Geschenke-App. Du bekommst
das Profil und eine Anweisung. Gib NUR die Änderungen zurück, als JSON in dieser Form –
lass jeden Schlüssel weg, der sich nicht ändert:
{{"zusammenfassung": "<neuer Satz über die Person>",
  "neue_wuensche": [{{"tag": "<Wunsch-Tag>", "gewicht": <0.5 bis 1.5>}}],
  "entfernte_wuensche": ["<Wunsch-Tag>"],
  "neue_ausschluesse": ["<art>:<wert>"],
  "entfernte_ausschluesse": ["<art>:<wert>"],
  "budget_max": <neue Obergrenze in Euro oder null für egal>}}
Ein neues Gewicht für einen bestehenden Wunsch steht in neue_wuensche.

{REGELN}"""

MIN_GEWICHT, MAX_GEWICHT = 0.0, 2.0


def _gewicht(wert) -> float:
    if isinstance(wert, bool):
        return 1.0
    try:
        g = float(wert)
    except (TypeError, ValueError):
        return 1.0
    return max(MIN_GEWICHT, min(MAX_GEWICHT, g))


def _liste(wert) -> list:
    return wert if isinstance(wert, list) else []


def _wuensche(roh) -> dict[str, float]:
    wuensche: dict[str, float] = {}
    for w in _liste(roh):
        if not isinstance(w, dict):
            continue
        tag = w.get("tag")
        if not isinstance(tag, str) or (tag not in THEMEN and tag not in LEBENSLAGEN):
            continue
        gewicht = _gewicht(w.get("gewicht", 1.0))
        wuensche[tag] = max(gewicht, wuensche.get(tag, gewicht))
    return wuensche


def _ausschluss_schluessel(roh) -> list[str]:
    ergebnis: list[str] = []
    for a in _liste(roh):
        schluessel = a.get("schluessel") if isinstance(a, dict) else a
        if not isinstance(schluessel, str):
            continue
        art, _, wert = schluessel.strip().partition(":")
        schluessel = f"{art}:{wert.strip().lower()}" if art == "wort" else f"{art}:{wert.strip()}"
        if ist_gueltiger_ausschluss(schluessel) and schluessel not in ergebnis:
            ergebnis.append(schluessel)
    return ergebnis


def _budget(wert) -> float | None:
    if isinstance(wert, bool) or not isinstance(wert, (int, float)) or wert <= 0:
        return None
    return float(wert)


def _profil(zusammenfassung: str, wuensche: dict[str, float], ausschluesse: list[str],
            budget: float | None) -> Profil:
    return Profil(
        zusammenfassung=zusammenfassung,
        wuensche=[Wunsch(tag=t, label=tag_label(t), gewicht=g) for t, g in wuensche.items()],
        ausschluesse=[Ausschluss(schluessel=s, label=label_fuer(s)) for s in ausschluesse],
        budget_max=budget,
    )


def bereinige_profil(roh: dict) -> Profil:
    zusammenfassung = roh.get("zusammenfassung")
    return _profil(
        zusammenfassung.strip() if isinstance(zusammenfassung, str) else "",
        _wuensche(roh.get("wuensche")),
        _ausschluss_schluessel(roh.get("ausschluesse")),
        _budget(roh.get("budget_max")),
    )


def wende_aenderung_an(profil: Profil, roh: dict) -> Profil:
    wuensche = {w.tag: w.gewicht for w in profil.wuensche}
    for tag in _liste(roh.get("entfernte_wuensche")):
        if isinstance(tag, str):
            wuensche.pop(tag, None)
    wuensche.update(_wuensche(roh.get("neue_wuensche")))

    entfernt = set(_ausschluss_schluessel(roh.get("entfernte_ausschluesse")))
    ausschluesse = [a.schluessel for a in profil.ausschluesse if a.schluessel not in entfernt]
    for s in _ausschluss_schluessel(roh.get("neue_ausschluesse")):
        if s not in ausschluesse:
            ausschluesse.append(s)

    budget = _budget(roh["budget_max"]) if "budget_max" in roh else profil.budget_max
    zusammenfassung = roh.get("zusammenfassung")
    if not isinstance(zusammenfassung, str) or not zusammenfassung.strip():
        zusammenfassung = profil.zusammenfassung
    return _profil(zusammenfassung.strip(), wuensche, ausschluesse, budget)


async def profil_aus_gespraech(nachrichten: list[ChatNachricht]) -> Profil:
    roh = await frage_json(SYSTEM_AUS_GESPRAECH, verlauf_text(nachrichten), max_tokens=1200)
    return bereinige_profil(roh)


async def profil_aendern(profil: Profil, anweisung: str) -> Profil:
    nutzer = json.dumps({"profil": profil.model_dump(), "anweisung": anweisung}, ensure_ascii=False)
    roh = await frage_json(SYSTEM_AENDERN, nutzer, max_tokens=1200)
    return wende_aenderung_an(profil, roh)
