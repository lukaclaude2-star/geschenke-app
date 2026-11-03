"""Beispielbilder für Ideenkarten einmalig von Pixabay holen (kostenlos, ohne Namensnennung).

Der Schlüssel (PIXABAY_KEY) steht nur in der lokalen .env – im Betrieb wird er nicht gebraucht,
die fertigen Bilder liegen in app/static/beispielbilder/.

  python scripts/hole_beispielbilder.py vorschlaege <ordner> [stichwort=suchbegriff ...]
      holt je Stichwort 4 Vorschläge und baut Übersichtsbögen zum Aussuchen
  python scripts/hole_beispielbilder.py uebernehmen <ordner> <auswahl.json>
      auswahl.json: {"stichwort": nummer 0–3} – lädt die gewählten Bilder groß und speichert sie
"""

import json
import sys
import time
from io import BytesIO
from pathlib import Path

import httpx
from PIL import Image, ImageDraw, ImageFont

WURZEL = Path(__file__).resolve().parent.parent
SUCHBEGRIFFE = Path(__file__).with_name("beispielbilder_suche.json")
ZIEL = WURZEL / "app" / "static" / "beispielbilder"
PIXABAY = "https://pixabay.com/api/"
ANZAHL = 4
BREITE, HOEHE = 800, 600


def schluessel() -> str:
    for zeile in (WURZEL / ".env").read_text(encoding="utf-8").splitlines():
        if zeile.startswith("PIXABAY_KEY="):
            return zeile.split("=", 1)[1].strip()
    sys.exit("PIXABAY_KEY fehlt in .env")


def zuschneiden(bild: Image.Image, breite: int, hoehe: int) -> Image.Image:
    """Mittig auf 4:3 zuschneiden, dann verkleinern."""
    bild = bild.convert("RGB")
    ziel = breite / hoehe
    b, h = bild.size
    if b / h > ziel:
        neu_b = round(h * ziel)
        bild = bild.crop(((b - neu_b) // 2, 0, (b - neu_b) // 2 + neu_b, h))
    else:
        neu_h = round(b / ziel)
        bild = bild.crop((0, (h - neu_h) // 2, b, (h - neu_h) // 2 + neu_h))
    return bild.resize((breite, hoehe), Image.LANCZOS)


def lade_bild(client: httpx.Client, url: str) -> bytes:
    """Pixabay bremst schnelle Downloads mit „Rate limit exceeded“ – dann warten und neu versuchen."""
    for versuch in range(12):
        antwort = client.get(url)
        if antwort.status_code == 200 and antwort.headers.get("content-type", "").startswith("image/"):
            return antwort.content
        time.sleep(min(10 * (versuch + 1), 60))
    raise RuntimeError(f"Bild nicht ladbar: {url}")


def grosse_url(foto: dict) -> str:
    """Das Foto in 1280 px aus dem offenen CDN – largeImageURL (pixabay.com/get/…) bremst Pixabay nach
    wenigen Downloads minutenlang (HTTP 429)."""
    if foto.get("klein", "").endswith("_150.jpg"):
        return foto["klein"].removesuffix("_150.jpg") + "_1280.jpg"
    return foto["gross"]


def vorschlaege(ordner: Path, ueberschreiben: dict[str, str]) -> None:
    ordner.mkdir(parents=True, exist_ok=True)
    begriffe = json.loads(SUCHBEGRIFFE.read_text(encoding="utf-8"))
    nur = list(ueberschreiben) or list(begriffe)
    treffer_datei = ordner / "treffer.json"
    treffer = json.loads(treffer_datei.read_text(encoding="utf-8")) if treffer_datei.exists() else {}
    key = schluessel()
    with httpx.Client(timeout=20) as client:
        for stichwort in nur:
            suche = ueberschreiben.get(stichwort) or begriffe[stichwort]
            antwort = client.get(PIXABAY, params={
                "key": key, "q": suche, "image_type": "photo", "orientation": "horizontal",
                "safesearch": "true", "per_page": ANZAHL, "min_width": 1000})
            antwort.raise_for_status()
            fotos = antwort.json().get("hits", [])[:ANZAHL]
            treffer[stichwort] = {"suche": suche, "fotos": [
                {"id": f["id"], "gross": f["largeImageURL"], "klein": f["previewURL"], "seite": f["pageURL"]}
                for f in fotos]}
            # Die kleinen Vorschaubilder liegen im offenen CDN und werden nicht gebremst.
            for i, f in enumerate(fotos):
                (ordner / f"{stichwort}_{i}.jpg").write_bytes(lade_bild(client, f["previewURL"]))
            print(f"{stichwort}: {len(fotos)} ({suche})")
            time.sleep(0.7)  # Pixabay erlaubt 100 Anfragen pro Minute
    treffer_datei.write_text(json.dumps(treffer, ensure_ascii=False, indent=1), encoding="utf-8")
    boegen(ordner, nur)


def boegen(ordner: Path, stichwoerter: list[str], pro_bogen: int = 8) -> None:
    """Übersichtsbögen: je Zeile ein Stichwort mit seinen 4 Vorschlägen (0–3)."""
    zelle_b, zelle_h, rand = 300, 225, 30
    schrift = ImageFont.load_default(size=22)
    for start in range(0, len(stichwoerter), pro_bogen):
        teil = stichwoerter[start:start + pro_bogen]
        bogen = Image.new("RGB", (ANZAHL * zelle_b, len(teil) * (zelle_h + rand)), "white")
        zeichnen = ImageDraw.Draw(bogen)
        for zeile, stichwort in enumerate(teil):
            y = zeile * (zelle_h + rand)
            zeichnen.text((5, y + 2), stichwort, fill="black", font=schrift)
            for i in range(ANZAHL):
                datei = ordner / f"{stichwort}_{i}.jpg"
                if datei.exists():
                    bild = zuschneiden(Image.open(datei), zelle_b - 6, zelle_h - 6)
                    bogen.paste(bild, (i * zelle_b + 3, y + rand + 3))
                    zeichnen.text((i * zelle_b + 8, y + rand + 6), str(i), fill="yellow", font=schrift,
                                  stroke_width=2, stroke_fill="black")
        bogen.save(ordner / f"bogen_{start // pro_bogen:02d}.jpg", quality=80)


def uebernehmen(ordner: Path, auswahl_datei: Path) -> None:
    treffer = json.loads((ordner / "treffer.json").read_text(encoding="utf-8"))
    auswahl = json.loads(auswahl_datei.read_text(encoding="utf-8"))
    ZIEL.mkdir(parents=True, exist_ok=True)
    quellen_datei = ZIEL / "quellen.json"
    quellen = json.loads(quellen_datei.read_text(encoding="utf-8")) if quellen_datei.exists() else {}
    with httpx.Client(timeout=30) as client:
        for stichwort, nummer in auswahl.items():
            foto = treffer[stichwort]["fotos"][nummer]
            ziel = ZIEL / f"{stichwort}.jpg"
            if ziel.exists() and quellen.get(stichwort) == foto["seite"]:
                continue  # schon geladen – nach einem Abbruch einfach neu starten
            bild = zuschneiden(Image.open(BytesIO(lade_bild(client, grosse_url(foto)))), BREITE, HOEHE)
            bild.save(ziel, quality=78, optimize=True, progressive=True)
            quellen[stichwort] = foto["seite"]
            quellen_datei.write_text(json.dumps(dict(sorted(quellen.items())), ensure_ascii=False, indent=1),
                                     encoding="utf-8")
            print(stichwort, "ok", flush=True)
            time.sleep(1.5)  # schnelle Downloads bremst Pixabay


if __name__ == "__main__":
    befehl, ordner = sys.argv[1], Path(sys.argv[2])
    if befehl == "vorschlaege":
        vorschlaege(ordner, dict((a.split("=", 1) + [""])[:2] for a in sys.argv[3:]))
    elif befehl == "uebernehmen":
        uebernehmen(ordner, Path(sys.argv[3]))
    else:
        sys.exit(__doc__)
