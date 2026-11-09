"""Baut katalog/katalog.json aus allen katalog/quellen/*.json.

Aufruf: python scripts/build_katalog.py   (braucht GROQ_API_KEY, optional NVIDIA_API_KEY, in Umgebung oder .env)
"""

import asyncio
import json
import logging
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import settings  # noqa: E402
from app.katalog.bauen import baue_katalog  # noqa: E402
from app.katalog.laden import lade_alle  # noqa: E402
from app.modelle import KatalogProdukt, QuellProdukt  # noqa: E402

WURZEL = Path(__file__).resolve().parent.parent


def lade_quellen() -> list[QuellProdukt]:
    quellen: list[QuellProdukt] = []
    for datei in sorted((WURZEL / "katalog" / "quellen").glob("*.json")):
        quellen.extend(QuellProdukt(**e) for e in json.loads(datei.read_text(encoding="utf-8")))
    return quellen


# Groq: 8.000 Token pro Minute je Modell, ein 20er-Stapel braucht ~6.500 → knapp eine Minute Abstand.
PAUSE_GROQ = 55
# NVIDIA gratis: rund 40 Anfragen pro Minute fürs ganze Konto; 8 Arbeiter à ~100 s bleiben weit darunter.
PAUSE_EXTERN = 5


def groq_arbeiter() -> dict[str, float]:
    """Das erste Groq-Modell bleibt für Chat, Profil und Ideen der App reserviert."""
    return {m: PAUSE_GROQ for m in settings.ki_modelle[1:]}


def arbeiter() -> dict[str, float]:
    """Mit NVIDIA-Schlüssel nur NVIDIA (kein Tageslimit, Groq-Kontingent bleibt für die App frei),
    sonst Groq. (GitHub Models ist seit 30.07.2026 eingestellt.)"""
    if not settings.nvidia_api_key:
        return groq_arbeiter()
    return {f"nvidia:{m}#{n}": PAUSE_EXTERN
            for m in settings.nvidia_modelle for n in range(settings.nvidia_arbeiter_je_modell)}


def braucht_ersatz(modelle: dict[str, float], bericht: dict[str, int]) -> bool:
    """Groq nur, wenn NVIDIA lief, aber kein einziges Produkt geschafft hat (Ausfall, Schlüssel ungültig)."""
    nur_nvidia = bool(modelle) and all(m.startswith("nvidia:") for m in modelle)
    return nur_nvidia and bericht["neu_verschlagwortet"] == 0 and bericht["noch_offen"] > 0


def frist_aus_umgebung() -> float | None:
    """KATALOG_MAX_MINUTEN: Danach keine neuen Stapel mehr, damit noch Zeit zum Speichern bleibt."""
    minuten = os.environ.get("KATALOG_MAX_MINUTEN")
    return float(minuten) * 60 if minuten else None


def katalog_text(katalog: list[KatalogProdukt]) -> str:
    """Ein Produkt pro Zeile, ohne Einrückung: bei ~50.000 Produkten deutlich unter GitHubs 50-MB-Warnung,
    und Git speichert nachts trotzdem nur die geänderten Zeilen."""
    zeilen = [json.dumps(p.model_dump(), ensure_ascii=False, separators=(",", ":")) for p in katalog]
    return "[\n" + ",\n".join(zeilen) + ("\n" if zeilen else "") + "]\n"


async def main() -> None:
    logging.basicConfig(level=logging.WARNING, format="%(message)s")
    ziel = WURZEL / settings.katalog_pfad
    # Obergrenze je Lauf in 20er-Stapeln; meist ist vorher das Tageskontingent aller Modelle leer.
    max_stapel = int(os.environ.get("KATALOG_MAX_STAPEL", "250"))
    modelle = arbeiter()
    print("Arbeiter:", ", ".join(modelle))
    frist = frist_aus_umgebung()
    start = time.monotonic()
    quellen = lade_quellen()
    katalog, bericht = await baue_katalog(quellen, lade_alle(str(ziel)), max_stapel=max_stapel,
                                          arbeiter=modelle, frist_sekunden=frist)
    if braucht_ersatz(modelle, bericht):
        print("NVIDIA hat nichts geschafft – Groq springt ein")
        rest = None if frist is None else max(0.0, frist - (time.monotonic() - start))
        katalog, bericht = await baue_katalog(quellen, katalog, max_stapel=max_stapel,
                                              arbeiter=groq_arbeiter(), frist_sekunden=rest)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_text(katalog_text(katalog), encoding="utf-8", newline="\n")
    for schluessel, wert in bericht.items():
        print(f"{schluessel}: {wert}")


if __name__ == "__main__":
    asyncio.run(main())
