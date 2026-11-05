"""Macht aus den variablen Google-Fonts-Dateien feste Schnitte für die App (DESIGN.md 3).

Variable Achsen wie SOFT lassen sich in SwiftUI nur umständlich setzen und Dynamic Type
greift dann nicht sauber. Feste Schnitte mit eigenem PostScript-Namen gehen mit
`Font.custom(_:size:relativeTo:)`.

Aufruf (Quellen von github.com/google/fonts, ofl/fraunces und ofl/nunitosans):
    python -P ios/werkzeuge/schriften/instanzen.py <Fraunces[...].ttf> <NunitoSans[...].ttf>
    python -P ios/werkzeuge/schriften/instanzen.py --pruefen
"""
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ZIEL = Path(__file__).resolve().parents[2] / "Geschenke" / "Schriften"

# Wie in der Ansicht „Schriftvorschläge“ (Luka, 05.11.2026): Fraunces Bold, SOFT 100.
# WONK bleibt auf dem Standard 1, so hat Google Fonts die Vorschau ausgeliefert.
# opsz 28 liegt zwischen den Größen der Überschriften (20 bis 34 pt).
FRAUNCES = [("Fraunces Soft", "Bold", "FrauncesSoft-Bold",
             {"opsz": 28, "wght": 700, "SOFT": 100, "WONK": 1})]

NUNITO_SANS = [("Nunito Sans", stil, f"NunitoSans-{stil}",
                {"opsz": 12, "wght": gewicht, "wdth": 100, "YTLC": 500})
               for stil, gewicht in (("Regular", 400), ("SemiBold", 600), ("Bold", 700), ("ExtraBold", 800))]


def namen_setzen(schrift: TTFont, familie: str, stil: str, postscript: str) -> None:
    tabelle = schrift["name"]
    # Namen der variablen Datei ersetzen (nameID 25 ist das Präfix für variable Schnitte).
    tabelle.names = [n for n in tabelle.names if n.nameID not in (1, 2, 3, 4, 6, 16, 17, 25)]
    werte = {1: f"{familie} {stil}" if stil not in ("Regular", "Bold") else familie,
             2: stil if stil in ("Regular", "Bold") else "Regular",
             3: f"{postscript};geschenke-app", 4: f"{familie} {stil}", 6: postscript,
             16: familie, 17: stil}
    for name_id, wert in werte.items():
        tabelle.setName(wert, name_id, 3, 1, 0x409)
        tabelle.setName(wert, name_id, 1, 0, 0)
    for tabelle_name in ("STAT",):
        if tabelle_name in schrift:
            del schrift[tabelle_name]


def bauen(quelle: Path, schnitte: list) -> None:
    for familie, stil, postscript, achsen in schnitte:
        schrift = instantiateVariableFont(TTFont(quelle), achsen)
        namen_setzen(schrift, familie, stil, postscript)
        if "DSIG" in schrift:
            del schrift["DSIG"]  # Signatur passt nach dem Umbau nicht mehr
        ziel = ZIEL / f"{postscript}.ttf"
        schrift.save(ziel)
        print("geschrieben:", ziel.name)


def pruefen() -> int:
    erwartet = [s[2] for s in FRAUNCES + NUNITO_SANS]
    fehler = 0
    for postscript in erwartet:
        datei = ZIEL / f"{postscript}.ttf"
        if not datei.exists():
            print("FEHLT:", datei.name)
            fehler += 1
            continue
        schrift = TTFont(datei)
        name = schrift["name"].getDebugName(6)
        statisch = "fvar" not in schrift
        ok = name == postscript and statisch
        fehler += not ok
        print(f"{'ok ' if ok else 'FEHLER'} {datei.name}: PostScript={name}, statisch={statisch}")
    return fehler


if __name__ == "__main__":
    if sys.argv[1:] == ["--pruefen"]:
        sys.exit(1 if pruefen() else 0)
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    ZIEL.mkdir(parents=True, exist_ok=True)
    bauen(Path(sys.argv[1]), FRAUNCES)
    bauen(Path(sys.argv[2]), NUNITO_SANS)
    sys.exit(1 if pruefen() else 0)
