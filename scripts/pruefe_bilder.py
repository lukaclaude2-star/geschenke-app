"""Prüft die Produktfotos des Katalogs und schreibt katalog/bilder.json.

Aufruf: python scripts/pruefe_bilder.py   (BILDER_MAX_MINUTEN begrenzt die Laufzeit, Standard 10)
Was in einem Lauf nicht drankommt, prüft der nächste; ungeprüfte Bilder zeigt der Server weiter.
"""

import asyncio
import os
import sys
from collections import Counter
from datetime import date
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import settings  # noqa: E402
from app.katalog.bildpruefung import (app_bild_url, bild_kaputt, bilder_pfad, lade_stand,  # noqa: E402
                                      pruefe_bilder, stand_text)
from app.katalog.laden import lade_alle, zeigbar  # noqa: E402

WURZEL = Path(__file__).resolve().parent.parent


async def main() -> None:
    katalog_pfad = WURZEL / settings.katalog_pfad
    ziel = bilder_pfad(katalog_pfad)
    urls = sorted({app_bild_url(p.bild_url) for p in zeigbar(lade_alle(str(katalog_pfad)))})
    alt = lade_stand(ziel)
    frist = float(os.environ.get("BILDER_MAX_MINUTEN", "10")) * 60
    stand = await pruefe_bilder(urls, alt, date.today(), frist_sekunden=frist)
    ziel.write_text(stand_text(stand), encoding="utf-8", newline="\n")

    geprueft = sum(1 for u, e in stand.items() if alt.get(u) != e)
    kaputt = [u for u, e in stand.items() if bild_kaputt(e)]
    print(f"Bilder im Katalog: {len(urls)}, geprüft: {geprueft}, noch nie geprüft: {len(urls) - len(stand)}")
    print(f"kaputt (werden nicht gezeigt): {len(kaputt)}")
    # Fallen bei einem Shop fast alle Bilder durch, sperrt er vielleicht nur den Prüf-Rechner.
    for host, anzahl in Counter(urlsplit(u).netloc for u in kaputt).most_common(10):
        print(f"  {anzahl:5d}  {host}")


if __name__ == "__main__":
    asyncio.run(main())
