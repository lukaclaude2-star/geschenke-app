"""Erzeugt app/static/icon.png (256 px) aus dem App-Icon, damit die SideStore-Quelle dasselbe
Icon zeigt wie das iPhone.

Aufruf (braucht Pillow): python scripts/mache_icon.py
"""

from pathlib import Path

from PIL import Image

WURZEL = Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "ios" / "Geschenke" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
ZIEL = WURZEL / "app" / "static" / "icon.png"


def main() -> None:
    Image.open(QUELLE).convert("RGB").resize((256, 256), Image.LANCZOS).save(ZIEL, optimize=True)
    print("geschrieben:", ZIEL)


if __name__ == "__main__":
    main()
