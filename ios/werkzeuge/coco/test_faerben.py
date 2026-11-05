"""Tests für faerben.py.

Aufruf (aus dem Repo-Wurzelordner):
    python -X utf8 -m unittest discover -s ios/werkzeuge/coco -v
"""
import json
import re
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from faerben import FARBEN, HIER, NAMEN, VARIANTEN, faerbe, main, plan_fuer
from zerlegen import teilpfade


def original(motiv: str) -> str:
    return (HIER / "svg" / f"{motiv}.svg").read_text(encoding="utf-8")


def gefaerbt(motiv: str, variante: str) -> str:
    return faerbe(original(motiv), plan_fuer(motiv, variante), VARIANTEN[variante])


def linien_teile(motiv: str) -> list[dict]:
    pfade = re.findall(r"<path[^>]*>", original(motiv))
    linie = next(p for p in pfade if 'fill="#fff"' not in p)
    return teilpfade(re.search(r'\sd="([^"]*)"', linie).group(1))


class FaerbenTest(unittest.TestCase):
    def test_nur_attribute(self):
        # iOS zeichnet SVGs aus dem Asset-Katalog ohne CSS und ohne var(), Maße in mm sind unsicher.
        for motiv in FARBEN:
            for variante in VARIANTEN:
                svg = gefaerbt(motiv, variante)
                for verboten in ("var(", "style=", "<style", "class=", 'mm"'):
                    self.assertNotIn(verboten, svg, f"{motiv} {variante}: {verboten}")

    def test_gueltiges_xml(self):
        for motiv in FARBEN:
            for variante in VARIANTEN:
                wurzel = ET.fromstring(gefaerbt(motiv, variante))
                self.assertEqual(wurzel.tag, "{http://www.w3.org/2000/svg}svg", f"{motiv} {variante}")

    def test_keine_ungefaerbten_reste(self):
        for motiv in FARBEN:
            for variante in VARIANTEN:
                svg = gefaerbt(motiv, variante)
                self.assertNotIn('fill="#fff"', svg, f"{motiv} {variante}")
                self.assertNotIn('fill="#030303"', svg, f"{motiv} {variante}")
                # Jeder Pfad hat eine eigene Füllung, auch der Linienpfad der Katze ohne fill im Original.
                for pfad in re.findall(r"<path[^>]*>", svg):
                    self.assertIn("fill=", pfad, f"{motiv} {variante}")

    def test_farben_der_variante(self):
        abend = gefaerbt("animals_cat_sleeping2", "abend")
        self.assertIn('fill="#D7843A"', abend)
        self.assertIn('fill="#7B5930"', abend)
        hell = gefaerbt("animals_cat_sleeping2", "hell")
        self.assertIn('fill="#D07A2C"', hell)
        self.assertIn('fill="#23160C"', hell)
        self.assertNotIn('fill="#7B5930"', hell)

    def test_kranz_im_abendlicht_moos(self):
        self.assertEqual(plan_fuer("christmas_holly_3", "abend")["basis"], "moos")
        self.assertEqual(plan_fuer("christmas_holly_3", "hell")["basis"], "moosdunkel")
        self.assertNotIn(f'fill="{VARIANTEN["abend"]["moosdunkel"]}"', gefaerbt("christmas_holly_3", "abend"))
        self.assertIn(f'fill="{VARIANTEN["hell"]["moosdunkel"]}"', gefaerbt("christmas_holly_3", "hell"))

    def test_luecke_bleibt_leer(self):
        # Flächen nutzen die absolut umgeschriebenen Teilpfade, der Linienpfad behält sein Original-d.
        # Kommt ein Teilpfad in der Ausgabe vor, wurde er gefüllt.
        geschenk = linien_teile("unwrap_gift_3")
        svg = gefaerbt("unwrap_gift_3", "abend")
        self.assertNotIn(geschenk[30]["d"], svg)
        self.assertIn(geschenk[35]["d"], svg)
        stapel = linien_teile("present_5")
        svg = gefaerbt("present_5", "hell")
        self.assertNotIn(stapel[75]["d"], svg)
        self.assertIn(stapel[31]["d"], svg)

    def test_masse_aus_viewbox(self):
        kopf = re.search(r"<svg[^>]*>", gefaerbt("animals_cat_sleeping2", "abend")).group(0)
        self.assertIn('width="163.52823"', kopf)
        self.assertIn('height="106.78658"', kopf)
        self.assertIn('viewBox="0 0 163.52823 106.78658"', kopf)
        self.assertIn('fill="#7B5930"', kopf)

    def test_contents_json(self):
        with tempfile.TemporaryDirectory() as ordner:
            ziel = Path(ordner) / "Assets.xcassets"
            main(ziel)
            wurzel = json.loads((ziel / "Contents.json").read_text(encoding="utf-8"))
            self.assertEqual(wurzel, {"info": {"author": "xcode", "version": 1}})
            for name in NAMEN.values():
                satz = ziel / f"coco-{name}.imageset"
                self.assertEqual(sorted(p.name for p in satz.iterdir()),
                                 ["Contents.json", f"{name}-abend.svg", f"{name}-hell.svg"])
            inhalt = json.loads((ziel / "coco-katze.imageset" / "Contents.json").read_text(encoding="utf-8"))
            bilder = inhalt["images"]
            self.assertEqual(len(bilder), 2)
            hell = next(b for b in bilder if b["filename"] == "katze-hell.svg")
            abend = next(b for b in bilder if b["filename"] == "katze-abend.svg")
            self.assertNotIn("appearances", hell)
            self.assertEqual(abend["appearances"], [{"appearance": "luminosity", "value": "dark"}])
            self.assertEqual(inhalt["properties"], {"preserves-vector-representation": True})

    def test_bildnamen(self):
        self.assertEqual(NAMEN, {"animals_cat_sleeping2": "katze", "unwrap_gift_3": "geschenk",
                                 "christmas_holly_3": "kranz", "present_5": "stapel",
                                 "family_love-7": "familie", "food_tea": "tee"})
        self.assertEqual(set(NAMEN), set(FARBEN))


if __name__ == "__main__":
    unittest.main()
