import json
from pathlib import Path

from app.config import settings
from app.katalog.bildpruefung import app_bild_url, bild_kaputt, bilder_pfad, lade_stand
from app.modelle import KatalogProdukt


def zeigbar(katalog: list[KatalogProdukt]) -> list[KatalogProdukt]:
    """Nur Produkte mit ausreichender Geschenk-Note (Ramsch-Filter Stufe 2)."""
    return [p for p in katalog if p.note >= settings.min_note]


def lade_alle(pfad: str) -> list[KatalogProdukt]:
    datei = Path(pfad)
    if not datei.exists():
        return []
    return [KatalogProdukt(**e) for e in json.loads(datei.read_text(encoding="utf-8"))]


def lade_katalog(pfad: str) -> list[KatalogProdukt]:
    """Der Katalog, wie der Server ihn zeigt: ohne Produkte, deren Foto in der App nicht lädt."""
    bilder = lade_stand(bilder_pfad(pfad))
    return [p for p in zeigbar(lade_alle(pfad)) if not bild_kaputt(bilder.get(app_bild_url(p.bild_url)))]
