"""Lädt Awin-Produktfeeds → katalog/quellen/awin-<shop>.json (danach build_katalog.py wie immer).

Aufrufe:
  python scripts/lade_awin_feeds.py                          alle Feeds aus AWIN_FEEDS
  python scripts/lade_awin_feeds.py --datei feed.csv.gz --shop "mydays"   eine lokale Datei

AWIN_FEEDS (in .env oder als GitHub-Secret, nie im Repo – die Download-Adressen enthalten den
Awin-API-Schlüssel, Grundbaustein 9): {"mydays": "https://…", "Jochen Schweizer": "https://…"}
Die Adresse je Partner erzeugt Awin unter Toolbox → Create-a-Feed (CSV, Spalten „Select All“).

Der Ramsch-Filter Stufe 1 läuft hier schon; Stufe 2 (KI-Note) beim Katalogbau.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import settings  # noqa: E402
from app.katalog.awin import feed_text, produkte_aus_feed  # noqa: E402
from app.katalog.jsonld import _slug  # noqa: E402
from app.katalog.regeln import pruefe_regeln  # noqa: E402

WURZEL = Path(__file__).resolve().parent.parent
# Ein Feed kann Zehntausende Produkte haben; der Katalog soll gemischt bleiben und die
# Verschlagwortung (KI-Kontingent) nicht für einen einzigen Shop aufbrauchen.
MAX_JE_SHOP = 300


def speichere(shop: str, inhalt: bytes, max_je_shop: int = MAX_JE_SHOP) -> str:
    produkte = produkte_aus_feed(feed_text(inhalt), shop)
    gruende = Counter(pruefe_regeln(p) for p in produkte)
    gut = [p for p in produkte if pruefe_regeln(p) is None][:max_je_shop]
    datei = WURZEL / "katalog" / "quellen" / f"awin-{_slug(shop)}.json"
    if gut:
        datei.write_text(json.dumps([p.model_dump(exclude_none=True) for p in gut], ensure_ascii=False,
                                    indent=1) + "\n", encoding="utf-8")
    raus = ", ".join(f"{g}: {n}" for g, n in gruende.most_common() if g)
    return f"{len(gut):>4} übernommen / {len(produkte):>5} im Feed  {shop}" + (f"  (raus: {raus})" if raus else "")


def main() -> None:
    argumente = argparse.ArgumentParser()
    argumente.add_argument("--datei")
    argumente.add_argument("--shop")
    argumente.add_argument("--max", type=int, default=MAX_JE_SHOP)
    a = argumente.parse_args()

    if a.datei:
        print(speichere(a.shop or Path(a.datei).stem, Path(a.datei).read_bytes(), a.max))
        return

    feeds = settings.awin_feeds
    if not feeds:
        sys.exit("AWIN_FEEDS ist leer – erst nach der Annahme bei Awin eintragen.")
    with httpx.Client(timeout=120, follow_redirects=True) as client:
        for shop, url in feeds.items():
            try:
                antwort = client.get(url)
                antwort.raise_for_status()
            except httpx.HTTPError as fehler:
                # Kein Schlüssel in der Ausgabe: nur Shop und Fehlerart.
                print(f"Fehler {type(fehler).__name__}  {shop}")
                continue
            print(speichere(shop, antwort.content, a.max))


if __name__ == "__main__":
    main()
