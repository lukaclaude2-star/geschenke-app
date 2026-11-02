"""Profil aus dem Gespräch ableiten und per Chat ändern.

Die KI liefert Rohdaten; bereinige_profil lässt nur Vokabular durch (Grundbaustein 3/5).
"""

import json

from app.gespraech import verlauf_text
from app.ki import frage_json
from app.modelle import Ausschluss, ChatNachricht, Profil, Wunsch
from app.vokabular import (EIGENSCHAFTEN, FARBEN, LEBENSLAGEN, THEMEN, ist_gueltiger_ausschluss,
                           label_fuer, tag_label)

FORMAT = f"""Antworte nur mit JSON:
{{"zusammenfassung": "ein Satz über die Person",
  "wuensche": [{{"tag": "...", "gewicht": 0.5-1.5}}],
  "ausschluesse": ["farbe:schwarz", "eigenschaft:alkohol", "thema:wein", "wort:katze"],
  "budget_max": Zahl oder null}}

Erlaubte Wunsch-Tags: {", ".join(list(THEMEN) + list(LEBENSLAGEN))}
Ausschlüsse: "thema:<Wunsch-Tag>", "farbe:<{"|".join(FARBEN)}>",
"eigenschaft:<{"|".join(EIGENSCHAFTEN)}>" oder – wenn nichts davon passt – "wort:<kürzester
treffender Wortstamm, klein>" (z. B. "nichts mit Katzen-Motiv" → "wort:katze").
- gewicht: 1.5 = liebt es / ganz wichtig, 1.0 = mag es, 0.5 = nebenbei.
- Alles, was die Person nicht mag, nicht darf oder schon hat, wird ein Ausschluss.
- budget_max: Obergrenze in Euro, null wenn egal oder nicht genannt."""

SYSTEM_AUS_GESPRAECH = "Du wertest ein Gespräch in einer Geschenke-App aus.\n" + FORMAT

SYSTEM_AENDERN = (
    "Du änderst ein gespeichertes Personen-Profil einer Geschenke-App. Du bekommst das Profil "
    "und eine Anweisung. Ändere nur, was die Anweisung betrifft; alles andere bleibt genau so.\n"
    + FORMAT
)

MIN_GEWICHT, MAX_GEWICHT = 0.0, 2.0


def _gewicht(wert) -> float:
    try:
        g = float(wert)
    except (TypeError, ValueError):
        return 1.0
    return max(MIN_GEWICHT, min(MAX_GEWICHT, g))


def bereinige_profil(roh: dict) -> Profil:
    wuensche: dict[str, float] = {}
    for w in roh.get("wuensche") or []:
        if not isinstance(w, dict):
            continue
        tag = w.get("tag")
        if tag not in THEMEN and tag not in LEBENSLAGEN:
            continue
        gewicht = _gewicht(w.get("gewicht", 1.0))
        wuensche[tag] = max(gewicht, wuensche.get(tag, gewicht))

    ausschluesse: list[Ausschluss] = []
    for a in roh.get("ausschluesse") or []:
        schluessel = a.get("schluessel") if isinstance(a, dict) else a
        if not isinstance(schluessel, str):
            continue
        schluessel = schluessel.strip()
        art, _, wert = schluessel.partition(":")
        schluessel = f"{art}:{wert.strip().lower()}" if art == "wort" else schluessel
        if ist_gueltiger_ausschluss(schluessel) and schluessel not in [x.schluessel for x in ausschluesse]:
            ausschluesse.append(Ausschluss(schluessel=schluessel, label=label_fuer(schluessel)))

    budget = roh.get("budget_max")
    if isinstance(budget, bool) or not isinstance(budget, (int, float)) or budget <= 0:
        budget = None

    zusammenfassung = roh.get("zusammenfassung")
    return Profil(
        zusammenfassung=zusammenfassung.strip() if isinstance(zusammenfassung, str) else "",
        wuensche=[Wunsch(tag=t, label=tag_label(t), gewicht=g) for t, g in wuensche.items()],
        ausschluesse=ausschluesse,
        budget_max=float(budget) if budget is not None else None,
    )


async def profil_aus_gespraech(nachrichten: list[ChatNachricht]) -> Profil:
    roh = await frage_json(SYSTEM_AUS_GESPRAECH, verlauf_text(nachrichten), max_tokens=1200)
    return bereinige_profil(roh)


async def profil_aendern(profil: Profil, anweisung: str) -> Profil:
    nutzer = json.dumps({"profil": profil.model_dump(), "anweisung": anweisung}, ensure_ascii=False)
    roh = await frage_json(SYSTEM_AENDERN, nutzer, max_tokens=1200)
    return bereinige_profil(roh)
