"""Erzeugt app/static/icon.png (Geschenk in Gold auf Nachtblau) ohne Zusatzpakete.

SideStore braucht in der Quelle eine Icon-Adresse. Aufruf: python scripts/mache_icon.py
"""

import struct
import zlib
from pathlib import Path

GROESSE = 256
NACHTBLAU = (0x11, 0x13, 0x1C)
GOLD = (0xE0, 0xB8, 0x4C)
DUNKELGOLD = (0xB8, 0x92, 0x34)


def farbe(x: int, y: int) -> tuple[int, int, int]:
    # Paket: 64..192 breit, 100..208 hoch; Deckel 56..200 breit, 76..112 hoch
    band_senkrecht = 120 <= x < 136
    if 76 <= y < 112 and 56 <= x < 200:
        return DUNKELGOLD if band_senkrecht else GOLD
    if 112 <= y < 208 and 68 <= x < 188:
        return DUNKELGOLD if band_senkrecht else GOLD
    # Schleife: zwei Kreise über dem Deckel
    for mx in (108, 148):
        if (x - mx) ** 2 + (y - 62) ** 2 < 16 ** 2 and not (x - mx) ** 2 + (y - 62) ** 2 < 8 ** 2:
            return GOLD
    return NACHTBLAU


def png() -> bytes:
    zeilen = b"".join(
        b"\x00" + bytes(c for x in range(GROESSE) for c in farbe(x, y)) for y in range(GROESSE)
    )

    def block(art: bytes, daten: bytes) -> bytes:
        return struct.pack(">I", len(daten)) + art + daten + struct.pack(">I", zlib.crc32(art + daten))

    kopf = struct.pack(">IIBBBBB", GROESSE, GROESSE, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + block(b"IHDR", kopf) + block(b"IDAT", zlib.compress(zeilen, 9)) + block(b"IEND", b"")


if __name__ == "__main__":
    ziel = Path(__file__).resolve().parent.parent / "app" / "static" / "icon.png"
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_bytes(png())
    print(ziel, ziel.stat().st_size, "Bytes")
