"""Färbt die Coco-Motive je Farbwelt und schreibt sie als Asset-Katalog für die App.

Aufruf (aus dem Repo-Wurzelordner):
    python -X utf8 ios/werkzeuge/coco/faerben.py

Grundlage ist das von Luka abgenommene Muster „Coco-Test 2“ (Färbelogik wie `motiv()` in
dessen `bauen.py`, Farben aus docs/design/palette-zuhause.md). iOS zeichnet SVGs aus dem
Asset-Katalog nur eingeschränkt (kein CSS, keine var(), Maße in mm unsicher), deshalb stehen
alle Farben als Attribute im SVG. Je Motiv entsteht ein Bildsatz mit einer hellen und einer
dunklen Variante, iOS wählt sie selbst nach dem Dunkelmodus.
"""
import json
import re
import sys
from pathlib import Path

HIER = Path(__file__).resolve().parent
sys.path.insert(0, str(HIER))

from zerlegen import innen, loecher, teilpfade  # noqa: E402

STANDARD_ZIEL = HIER.parent.parent / "Geschenke" / "Assets.xcassets"

# Bildnamen in der App: coco-<name>.
NAMEN = {
    "animals_cat_sleeping2": "katze",
    "unwrap_gift_3": "geschenk",
    "christmas_holly_3": "kranz",
    "present_5": "stapel",
    "family_love-7": "familie",
    "food_tea": "tee",
}

# Pro Motiv wenige Farben: ein Gegenstand = eine Farbe (aus bauen.py im Coco-Test).
# "luecken": Bereiche, die im Original nicht weiß sind. Sie bleiben leer, damit der
#            Kartenhintergrund durchscheint.
# "bereiche": Nummer -> Farbe, alles andere bekommt "rest".
# "basis_abend": Grundfarbe im Abendlicht, falls sie dort abweicht.
FARBEN = {
    "unwrap_gift_3": {"basis": "licht", "rest": "licht", "luecken": {30},
                      "bereiche": {35: "haut", 40: "braun", 41: "braun", 42: "braun",
                                   1: "rot", 17: "rot", 25: "rot"}},
    # Im Abendlicht wäre moosdunkel auf der dunklen Karte zu matt (Coco-Test 2).
    "christmas_holly_3": {"basis": "moosdunkel", "basis_abend": "moos", "rest": "moos",
                          "klein": "rot", "klein_anteil": 0.0012,
                          "min_anteil": 0.0003, "luecken": {9, 10, 36, 37}, "bereiche": {}},
    "present_5": {"basis": "rot", "rest": "rot", "luecken": {75, 93, 94},
                  # große und kleine Schachtel rot (Grundfarbe), runde gelb, flache grün
                  "bereiche": {**{i: "licht" for i in (31, 63, 65, 77, 88)},
                               **{i: "moos" for i in (1, 3, 5, 7, 9, 10, 15, 18, 19, 21, 22)}}},
    "family_love-7": {"basis": "kupfer", "rest": "braun", "luecken": set(),
                      "bereiche": {4: "haut", 11: "haut", 9: "rot"}},
    "food_tea": {"basis": "licht", "rest": "licht", "luecken": {7},
                 "bereiche": {3: "braun", 4: "braun", 5: "braun", 8: "rot", 9: "rot"}},
    "animals_cat_sleeping2": {"basis": "kupfer", "rest": "kupfer", "luecken": set(), "bereiche": {}},
}

# Farbwerte je Farbwelt (docs/design/palette-zuhause.md). Linie Abendlicht ist Cognac (Coco-Test 2).
VARIANTEN = {
    "abend": {"linie": "#7B5930", "rot": "#C9573A", "kupfer": "#D7843A", "licht": "#EFB249",
              "haut": "#E2B98C", "braun": "#7B5930", "moos": "#86A04B", "moosdunkel": "#5F7A33"},
    "hell": {"linie": "#23160C", "rot": "#BE4A2E", "kupfer": "#D07A2C", "licht": "#EFB249",
             "haut": "#EBC499", "braun": "#7B5930", "moos": "#7C9A42", "moosdunkel": "#566F2D"},
}


def plan_fuer(motiv: str, variante: str) -> dict:
    plan = dict(FARBEN[motiv])
    if variante == "abend" and "basis_abend" in plan:
        plan["basis"] = plan["basis_abend"]
    return plan


def faerbe(svg: str, plan: dict, farben: dict[str, str]) -> str:
    pfade = re.findall(r"<path[^>]*>", svg)
    linie = next(p for p in pfade if 'fill="#fff"' not in p)
    d = re.search(r'\sd="([^"]*)"', linie).group(1)
    transform = re.search(r'transform="([^"]*)"', linie)
    teile = teilpfade(d)
    gesamt = max(abs(t["flaeche"]) for t in teile)

    flaechen = []
    vergeben: dict[int, str] = {}
    for i in loecher(teile, plan.get("min_anteil", 0.002)):
        if i in plan["luecken"]:
            continue
        if i in plan["bereiche"]:
            name_farbe = plan["bereiche"][i]
        elif "klein" in plan and abs(teile[i]["flaeche"]) < gesamt * plan["klein_anteil"]:
            name_farbe = plan["klein"]
        else:
            name_farbe = plan["rest"]
        vergeben[i] = name_farbe
        flaechen.append(f'<path d="{teile[i]["d"]}" fill="{farben[name_farbe]}"/>')

    # Winzige Bereiche (unter der Schwelle) erben die Farbe des kleinsten
    # vergebenen Bereichs, in dem sie liegen. Sonst würde dort die Grundfarbe durchblitzen.
    for i in loecher(teile, 0.00002):
        if i in vergeben or i in plan["luecken"]:
            continue
        umgebend = [j for j in vergeben if innen(teile[i]["box"], teile[j]["box"])]
        if umgebend:
            j = min(umgebend, key=lambda k: abs(teile[k]["flaeche"]))
            flaechen.append(f'<path d="{teile[i]["d"]}" fill="{farben[vergeben[j]]}"/>')
    t_attr = f' transform="{transform.group(1)}"' if transform else ""
    gruppe = f'<g{t_attr}>{"".join(flaechen)}</g>'

    # Linienpfad ohne eigene Füllung bekommt sie direkt (nicht nur geerbt), sicher ist sicher.
    linie_neu = linie if "fill=" in linie else linie.replace("<path", f'<path fill="{farben["linie"]}"', 1)
    svg = svg.replace(linie, gruppe + linie_neu, 1)
    svg = svg.replace('fill="#fff"', f'fill="{farben[plan["basis"]]}"')
    svg = svg.replace('fill="#030303"', f'fill="{farben["linie"]}"')

    # Wurzel neu schreiben: Maße ohne Einheit aus der viewBox, Linienfarbe als Vorgabe.
    kopf = re.search(r"<svg\b[^>]*>", svg).group(0)
    viewbox = re.search(r'viewBox="([^"]*)"', kopf).group(1)
    _, _, breite, hoehe = viewbox.split()
    neuer_kopf = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}" '
                  f'width="{breite}" height="{hoehe}" fill="{farben["linie"]}">')
    return svg.replace(kopf, neuer_kopf, 1)


def schreibe_json(datei: Path, inhalt: dict) -> None:
    datei.write_text(json.dumps(inhalt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def main(ziel: Path = STANDARD_ZIEL) -> None:
    ziel.mkdir(parents=True, exist_ok=True)
    schreibe_json(ziel / "Contents.json", {"info": {"author": "xcode", "version": 1}})
    for motiv, name in NAMEN.items():
        original = (HIER / "svg" / f"{motiv}.svg").read_text(encoding="utf-8")
        satz = ziel / f"coco-{name}.imageset"
        satz.mkdir(exist_ok=True)
        for variante in VARIANTEN:
            svg = faerbe(original, plan_fuer(motiv, variante), VARIANTEN[variante])
            (satz / f"{name}-{variante}.svg").write_text(svg, encoding="utf-8", newline="\n")
        schreibe_json(satz / "Contents.json", {
            "images": [
                {"filename": f"{name}-hell.svg", "idiom": "universal"},
                {"appearances": [{"appearance": "luminosity", "value": "dark"}],
                 "filename": f"{name}-abend.svg", "idiom": "universal"},
            ],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True},
        })
    print(f"{len(NAMEN)} Bildsätze in {ziel}")


if __name__ == "__main__":
    main()
