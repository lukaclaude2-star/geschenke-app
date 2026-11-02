"""Baut katalog/katalog.json aus allen katalog/quellen/*.json.

Aufruf: python scripts/build_katalog.py   (braucht GROQ_API_KEY in Umgebung oder .env)
"""

import asyncio
import json
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


async def main() -> None:
    ziel = WURZEL / settings.katalog_pfad
    katalog, bericht = await baue_katalog(lade_quellen(), lade_alle(str(ziel)),
                                     pause_sekunden=20)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_text(
        json.dumps([p.model_dump() for p in katalog], ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    for schluessel, wert in bericht.items():
        print(f"{schluessel}: {wert}")


if __name__ == "__main__":
    asyncio.run(main())
