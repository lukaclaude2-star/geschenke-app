"""Rechtstexte (Impressum, Datenschutz, …) als Webseiten für App Store Connect.

Die Texte stehen genau einmal in rechtliches/rechtliches.json. Die App bündelt dieselbe Datei
und zeigt sie offline, der Server zeigt sie hier ohne Token. Die persönlichen Angaben sind im Repo
nur Platzhalter; die echten kommen aus IMPRESSUM_JSON (Render bzw. beim iOS-Build). Erlaubtes Format in den Absätzen:
`**fett**`, `[Text](https://…)` oder `[Text](mailto:…)` und ein „- “ am Anfang für Listenpunkte.
"""

from __future__ import annotations

import html
import json
import re
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from app.config import settings

PFAD = Path(__file__).parent.parent / "rechtliches" / "rechtliches.json"
DOKUMENTE = ("impressum", "datenschutz", "nutzung", "support", "lizenzen")

_PLATZHALTER = re.compile(r"\{\{(\w+)\}\}")
_FETT = re.compile(r"\*\*(.+?)\*\*")
# Nach dem Escapen: Ziel ohne Leerzeichen, Klammern und Anführungszeichen (die sind dann &quot;).
_LINK = re.compile(r"\[([^\]]+)\]\(((?:https://|mailto:)[^\s()&]*(?:&amp;[^\s()&]*)*)\)")

router = APIRouter()


@lru_cache(maxsize=1)
def _lade_gecacht(pfad: Path, impressum_json: str = "") -> dict:
    texte = json.loads(pfad.read_text(encoding="utf-8"))
    return mit_impressum(texte, impressum_json)


def mit_impressum(texte: dict, impressum_json: str) -> dict:
    """Echte Angaben aus IMPRESSUM_JSON über die Platzhalter legen (nur bekannte Schlüssel)."""
    if not impressum_json:
        return texte
    echte = json.loads(impressum_json)
    angaben = texte.get("angaben", {})
    return {**texte, "angaben": {**angaben, **{k: v for k, v in echte.items() if k in angaben}}}


def lade_texte(pfad: Path = PFAD) -> dict:
    return _lade_gecacht(pfad, settings.impressum_json)


def ausfuellen(text: str, texte: dict) -> str:
    werte = {**texte.get("angaben", {}), "stand": texte.get("stand", "")}
    return _PLATZHALTER.sub(lambda m: werte.get(m.group(1), m.group(0)), text)


def inline_html(text: str) -> str:
    sicher = html.escape(text, quote=True)
    sicher = _LINK.sub(r'<a href="\2">\1</a>', sicher)
    return _FETT.sub(r"<strong>\1</strong>", sicher)


def offene_angaben(texte: dict) -> list[str]:
    """Angaben, die noch Platzhalter in eckigen Klammern sind, z. B. „[Vor- und Nachname]“."""
    return [schluessel for schluessel, wert in texte.get("angaben", {}).items()
            if isinstance(wert, str) and wert.startswith("[") and wert.endswith("]")]


def _absaetze_html(absaetze: list[str], texte: dict) -> str:
    teile: list[str] = []
    liste: list[str] = []
    for absatz in absaetze:
        inhalt = inline_html(ausfuellen(absatz, texte))
        if absatz.startswith("- "):
            liste.append(f"<li>{inhalt[2:]}</li>")
            continue
        if liste:
            teile.append("<ul>" + "".join(liste) + "</ul>")
            liste = []
        teile.append(f"<p>{inhalt}</p>")
    if liste:
        teile.append("<ul>" + "".join(liste) + "</ul>")
    return "".join(teile)


_STIL = """
:root { color-scheme: light dark; --grund: #EFE6D6; --text: #23160C; --leise: #7B5930; --link: #9A3A24; }
@media (prefers-color-scheme: dark) { :root { --grund: #23160C; --text: #F1E3C6; --leise: #C0AE88; --link: #C2721E; } }
body { margin: 0; background: var(--grund); color: var(--text);
       font: 17px/1.55 -apple-system, "Segoe UI", system-ui, sans-serif; }
main { max-width: 680px; margin: 0 auto; padding: 32px 16px 64px; }
h1 { font-family: Georgia, serif; font-size: 30px; margin: 0 0 24px; }
h2 { font-size: 19px; margin: 28px 0 8px; }
p, li { margin: 0 0 10px; }
ul { padding-left: 22px; margin: 0 0 10px; }
a { color: var(--link); }
footer { margin-top: 40px; color: var(--leise); font-size: 14px; }
footer a { color: var(--leise); margin-right: 14px; }
"""


def seite(dokument_id: str, texte: dict | None = None) -> str | None:
    texte = texte if texte is not None else lade_texte()
    dokument = next((d for d in texte.get("dokumente", []) if d.get("id") == dokument_id), None)
    if dokument is None:
        return None
    titel = html.escape(ausfuellen(dokument["titel"], texte))
    inhalt = []
    for abschnitt in dokument["abschnitte"]:
        if abschnitt.get("ueberschrift"):
            inhalt.append(f"<h2>{inline_html(ausfuellen(abschnitt['ueberschrift'], texte))}</h2>")
        inhalt.append(_absaetze_html(abschnitt["absaetze"], texte))
    fuss = "".join(f'<a href="/{d}">{html.escape(_titel(d, texte))}</a>' for d in DOKUMENTE)
    return ("<!doctype html><html lang=\"de\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            f"<title>{titel} · Wunschwisch</title><style>{_STIL}</style></head>"
            f"<body><main><h1>{titel}</h1>{''.join(inhalt)}<footer>{fuss}</footer></main></body></html>")


def _titel(dokument_id: str, texte: dict) -> str:
    return next((d["titel"] for d in texte.get("dokumente", []) if d.get("id") == dokument_id), dokument_id)


def _route(dokument_id: str):
    def zeige() -> HTMLResponse:
        return HTMLResponse(seite(dokument_id))
    zeige.__name__ = f"zeige_{dokument_id}"
    return zeige


for _id in DOKUMENTE:
    router.add_api_route(f"/{_id}", _route(_id), methods=["GET"], response_class=HTMLResponse)
