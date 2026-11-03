"""Baut katalog/katalog.json aus allen katalog/quellen/*.json.

Aufruf: python scripts/build_katalog.py   (braucht GROQ_API_KEY in Umgebung oder .env)
"""

import asyncio
import json
import logging
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import settings  # noqa: E402
from app.katalog.bauen import baue_katalog  # noqa: E402
from app.katalog.laden import lade_alle  # noqa: E402
from app.modelle import QuellProdukt  # noqa: E402

WURZEL = Path(__file__).resolve().parent.parent


def lade_quellen() -> list[QuellProdukt]:
    quellen: list[QuellProdukt] = []
    for datei in sorted((WURZEL / "katalog" / "quellen").glob("*.json")):
        quellen.extend(QuellProdukt(**e) for e in json.loads(datei.read_text(encoding="utf-8")))
    return quellen


# Groq: 8.000 Token pro Minute je Modell, ein 20er-Stapel braucht ~6.500 → knapp eine Minute Abstand.
PAUSE_GROQ = 55


def arbeiter() -> dict[str, float]:
    """Jedes Modell mit eigenem Gratis-Kontingent bekommt einen Arbeiter; alle laufen gleichzeitig.

    Das erste Groq-Modell bleibt für Chat, Profil und Ideen der App reserviert. (GitHub Models war
    als dritte Quelle geplant, ist aber seit 30.07.2026 eingestellt.)"""
    return {m: PAUSE_GROQ for m in settings.ki_modelle[1:]}


async def main() -> None:
    logging.basicConfig(level=logging.WARNING, format="%(message)s")
    ziel = WURZEL / settings.katalog_pfad
    # Obergrenze je Lauf in 20er-Stapeln; meist ist vorher das Tageskontingent aller Modelle leer.
    max_stapel = int(os.environ.get("KATALOG_MAX_STAPEL", "250"))
    modelle = arbeiter()
    print("Arbeiter:", ", ".join(modelle))
    katalog, bericht = await baue_katalog(lade_quellen(), lade_alle(str(ziel)),
                                          max_stapel=max_stapel, arbeiter=modelle)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_text(
        json.dumps([p.model_dump() for p in katalog], ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    for schluessel, wert in bericht.items():
        print(f"{schluessel}: {wert}")


if __name__ == "__main__":
    asyncio.run(main())
