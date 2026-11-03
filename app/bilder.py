"""Beispielbilder für Ideenkarten: ein festes Foto pro Stichwort.

Ideenkarten führen zur Amazon-Suche, echte Amazon-Fotos gibt es erst mit der Produkt-API.
Die Fotos stammen von Pixabay (frei nutzbar ohne Namensnennung), liegen in
app/static/beispielbilder/ und werden mit scripts/hole_beispielbilder.py geholt.
In der App sind sie als „Beispielbild“ markiert. Ohne passendes Foto zeigt die Karte ihr Emoji.
"""

from pathlib import Path

from app.config import settings

ORDNER = Path(__file__).parent / "static" / "beispielbilder"
VORHANDEN = {datei.stem for datei in ORDNER.glob("*.jpg")}


def beispielbild(themen: list[str]) -> str | None:
    """Foto zum ersten Stichwort, das eins hat."""
    for thema in themen:
        if thema in VORHANDEN:
            return f"{settings.oeffentliche_url}/beispielbilder/{thema}.jpg"
    return None
