import json
from pathlib import Path

from app.modelle import KatalogProdukt


def lade_katalog(pfad: str) -> list[KatalogProdukt]:
    datei = Path(pfad)
    if not datei.exists():
        return []
    return [KatalogProdukt(**e) for e in json.loads(datei.read_text(encoding="utf-8"))]
