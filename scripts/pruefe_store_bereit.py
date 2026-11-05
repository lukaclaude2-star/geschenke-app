"""Was fehlt noch vor dem Einreichen im App Store?

    python scripts/pruefe_store_bereit.py          # Dateien und Angaben prüfen
    python scripts/pruefe_store_bereit.py --live   # zusätzlich die Rechtsseiten auf Render abrufen

Exit-Code 0 = alles da, 1 = etwas fehlt. Die vollständige Liste für Luka steht in
docs/app-store/checkliste.md; dieses Skript prüft nur, was sich automatisch prüfen lässt.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

WURZEL = Path(__file__).parent.parent
SEITEN = ("impressum", "datenschutz", "nutzung", "support", "lizenzen")


def probleme(wurzel: Path = WURZEL) -> list[str]:
    gefunden: list[str] = []
    texte = json.loads((wurzel / "rechtliches" / "rechtliches.json").read_text(encoding="utf-8"))
    for schluessel, wert in texte.get("angaben", {}).items():
        if isinstance(wert, str) and wert.startswith("[") and wert.endswith("]"):
            gefunden.append(f"Angabe offen in rechtliches/rechtliches.json: {schluessel}")
    if not (wurzel / "ios" / "Geschenke" / "PrivacyInfo.xcprivacy").exists():
        gefunden.append("Fehlt: ios/Geschenke/PrivacyInfo.xcprivacy")
    projekt = (wurzel / "ios" / "project.yml").read_text(encoding="utf-8")
    if "ITSAppUsesNonExemptEncryption" not in projekt:
        gefunden.append("Fehlt in ios/project.yml: ITSAppUsesNonExemptEncryption")
    return gefunden


def live_probleme(basis: str) -> list[str]:
    import httpx

    gefunden: list[str] = []
    # Render Free schläft: Die erste Anfrage darf bis zu 90 s dauern.
    with httpx.Client(timeout=90) as client:
        for seite in SEITEN:
            try:
                antwort = client.get(f"{basis}/{seite}")
            except httpx.HTTPError as fehler:
                gefunden.append(f"/{seite} nicht erreichbar: {type(fehler).__name__}")
                continue
            if antwort.status_code != 200:
                gefunden.append(f"/{seite} antwortet mit {antwort.status_code}")
            elif re.search(r"\[[^\]<>]{3,40}\]", antwort.text):
                gefunden.append(f"/{seite} zeigt noch Platzhalter")
    return gefunden


def main() -> int:
    gefunden = probleme()
    if "--live" in sys.argv:
        gefunden += live_probleme("https://geschenke.onrender.com")
    for zeile in gefunden:
        print("OFFEN:", zeile)
    if not gefunden:
        print("Alles, was sich automatisch prüfen lässt, ist bereit. Rest: docs/app-store/checkliste.md")
    return 1 if gefunden else 0


if __name__ == "__main__":
    sys.exit(main())
