"""Schreibt die Zuordnung Stichwort → Oberbereich für die App (Merkliste nach Kategorien).

Einzige Quelle bleibt `app/vokabular.py`; ein Test prüft, dass die Swift-Datei aktuell ist.
Aufruf: python scripts/bereiche_fuer_app.py
"""
from pathlib import Path

from app.vokabular import BEREICHE, THEMEN_NACH_BEREICH

SWIFT_DATEI = (Path(__file__).resolve().parents[1]
               / "ios" / "GeschenkeCore" / "Sources" / "GeschenkeCore" / "Bereiche.swift")


def ohne_emoji(label: str) -> str:
    """„🍳 Küche & Kochen“ → „Küche & Kochen“ (DESIGN.md 4: keine Emojis)."""
    return label.split(" ", 1)[1]


def swift_quelltext() -> str:
    zeilen = [
        "// Erzeugt von scripts/bereiche_fuer_app.py aus app/vokabular.py. Nicht von Hand ändern.",
        "",
        "/// Oberbereiche in der Reihenfolge des Vokabulars.",
        "let bereichReihenfolge: [String] = [",
        *[f'    "{schluessel}",' for schluessel in BEREICHE],
        "]",
        "",
        "/// Name eines Oberbereichs ohne Emoji, z. B. „Küche & Kochen“.",
        "let bereichNamen: [String: String] = [",
        *[f'    "{schluessel}": "{ohne_emoji(label)}",' for schluessel, label in BEREICHE.items()],
        "]",
        "",
        "/// Stichwort → Oberbereich.",
        "let themaBereich: [String: String] = [",
        *[f'    "{tag}": "{bereich}",' for bereich, themen in THEMEN_NACH_BEREICH.items() for tag in themen],
        "]",
        "",
    ]
    return "\n".join(zeilen)


if __name__ == "__main__":
    SWIFT_DATEI.write_text(swift_quelltext(), encoding="utf-8", newline="\n")
    print("geschrieben:", SWIFT_DATEI)
