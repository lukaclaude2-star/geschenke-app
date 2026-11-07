"""Misst, wie lange die Kartenauswahl bei großem Katalog braucht.

Aufruf: python scripts/miss_tempo.py [anzahl]   (Standard 25000; vervielfacht den echten Katalog)
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import settings  # noqa: E402
from app.katalog.laden import lade_katalog  # noqa: E402
from app.modelle import Ausschluss, Profil, Wunsch  # noqa: E402
from app.ranking import kandidaten  # noqa: E402

LAEUFE = 5


def main() -> None:
    ziel = int(sys.argv[1]) if len(sys.argv) > 1 else 25000
    echt = lade_katalog(settings.katalog_pfad)
    katalog = [p.model_copy(update={"id": f"{p.id}-{i}"})
               for i in range(-(-ziel // len(echt))) for p in echt][:ziel]
    profil = Profil(zusammenfassung="Messung", wuensche=[Wunsch(tag="kochen", label="Kochen", gewicht=1.0)],
                    ausschluesse=[Ausschluss(schluessel="eigenschaft:alkohol", label="Alkohol"),
                                  Ausschluss(schluessel="farbe:schwarz", label="Schwarz")])
    kandidaten(katalog, profil, set())  # einmal aufwärmen (Caches)
    start = time.perf_counter()
    for _ in range(LAEUFE):
        kandidaten(katalog, profil, set())
    print(f"s je Anfrage: {(time.perf_counter() - start) / LAEUFE:.3f} bei {len(katalog)}")


if __name__ == "__main__":
    main()
