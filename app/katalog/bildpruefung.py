"""Kommt das Produktfoto wirklich als Foto auf dem iPhone an?

Luka, 23.11.2026: manche Karten zeigen nur ein Geschenk-Symbol. Stichprobe: rund 8 % der
Katalogbilder laden nicht (tote Links, gesperrt, SVG-Logos statt Fotos, http statt https).
Der Nachtlauf prüft die Bilder und schreibt das Ergebnis nach katalog/bilder.json; der Server
zeigt Produkte mit kaputtem Bild nicht mehr (Grundbaustein 2: jede Karte soll funktionieren).
"""

import asyncio
import json
import time
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import quote, urlsplit, urlunsplit

import httpx

OK, KAPUTT, UNKLAR = "ok", "kaputt", "unklar"

# 403, 5xx, Zeitüberschreitung: oft nur vorübergehend oder eine Sperre gegen den Prüf-Rechner.
# Erst nach so vielen Fehlschlägen in Folge gilt das Bild als kaputt.
UNKLAR_BIS_KAPUTT = 3
OK_NEU_PRUEFEN_NACH = timedelta(days=14)
KAPUTT_NEU_PRUEFEN_NACH = timedelta(days=7)
JE_HOST = 4

# So meldet sich auch die App (AsyncImage über URLSession).
KOPFZEILEN = {"User-Agent": "Copperlid CFNetwork/3826.500.131 Darwin/24.5.0", "Accept": "image/*,*/*;q=0.8"}


def app_bild_url(url: str | None) -> str | None:
    """Die Adresse, wie die App sie lädt: iOS sperrt http (App Transport Security), und
    Leerzeichen oder Umlaute im Pfad müssen kodiert sein."""
    if not url:
        return url
    teile = urlsplit(url.strip())
    schema = "https" if teile.scheme == "http" else teile.scheme
    pfad = quote(teile.path, safe="/%:@!$&'()*+,;=-._~")
    anfrage = quote(teile.query, safe="/?%:@!$&'()*+,;=-._~")
    return urlunsplit((schema, teile.netloc, pfad, anfrage, teile.fragment))


def ist_foto(anfang: bytes) -> bool:
    """Am Dateianfang erkennen, ob das iPhone es als Foto anzeigt. SVG kann AsyncImage nicht,
    HTML ist eine Fehlerseite. Der Content-Type der Shops ist dafür zu unzuverlässig."""
    if anfang.startswith((b"\xff\xd8\xff", b"\x89PNG\r\n\x1a\n", b"GIF8", b"II*\x00", b"MM\x00*")):
        return True
    if anfang[:4] == b"RIFF" and anfang[8:12] == b"WEBP":
        return True
    return anfang[4:8] == b"ftyp" and anfang[8:12] in (b"avif", b"avis", b"heic", b"heix", b"mif1")


async def pruefe_bild(client: httpx.AsyncClient, url: str) -> str:
    try:
        async with client.stream("GET", url) as antwort:
            if antwort.status_code in (404, 410):
                return KAPUTT
            if antwort.status_code != 200:
                return UNKLAR
            anfang = b""
            async for stueck in antwort.aiter_bytes():
                anfang += stueck
                if len(anfang) >= 16:
                    break
            return OK if ist_foto(anfang) else KAPUTT
    except (httpx.HTTPError, httpx.InvalidURL, UnicodeError):
        return UNKLAR


def bild_kaputt(eintrag: dict | None) -> bool:
    if eintrag is None:
        return False
    return eintrag["s"] == KAPUTT or (eintrag["s"] == UNKLAR and eintrag["n"] >= UNKLAR_BIS_KAPUTT)


def faellig(eintrag: dict | None, heute: date) -> bool:
    if eintrag is None or eintrag["s"] == UNKLAR:
        return True
    alter = heute - date.fromisoformat(eintrag["d"])
    return alter >= (OK_NEU_PRUEFEN_NACH if eintrag["s"] == OK else KAPUTT_NEU_PRUEFEN_NACH)


def neuer_eintrag(alt: dict | None, ergebnis: str, heute: date) -> dict:
    """n zählt Fehlschläge in Folge; ein klares Ergebnis setzt ihn zurück."""
    fehlversuche = (alt["n"] if alt and alt["s"] == UNKLAR else 0) + 1 if ergebnis == UNKLAR else 0
    return {"s": ergebnis, "d": heute.isoformat(), "n": fehlversuche}


def reihenfolge(urls: list[str], alt: dict[str, dict], heute: date) -> list[str]:
    """Fällige Adressen, noch nie geprüfte zuerst, dann die am längsten nicht geprüften."""
    offen = [u for u in urls if faellig(alt.get(u), heute)]
    return sorted(offen, key=lambda u: (u in alt, alt[u]["d"] if u in alt else ""))


async def pruefe_bilder(urls: list[str], alt: dict[str, dict], heute: date,
                        frist_sekunden: float | None = None, parallel: int = 32,
                        transport: httpx.AsyncBaseTransport | None = None) -> dict[str, dict]:
    """Prüft die fälligen Adressen bis zur Frist; liefert den neuen Stand für alle `urls`
    (Adressen, die nicht mehr im Katalog sind, fallen heraus)."""
    stand = {u: alt[u] for u in urls if u in alt}
    start = time.monotonic()
    gesamt = asyncio.Semaphore(parallel)
    je_host: dict[str, asyncio.Semaphore] = {}

    async def eine(client: httpx.AsyncClient, url: str) -> None:
        host = urlsplit(url).netloc
        async with gesamt, je_host.setdefault(host, asyncio.Semaphore(JE_HOST)):
            if frist_sekunden is not None and time.monotonic() - start > frist_sekunden:
                return
            stand[url] = neuer_eintrag(stand.get(url), await pruefe_bild(client, url), heute)

    async with httpx.AsyncClient(headers=KOPFZEILEN, follow_redirects=True, transport=transport,
                                 timeout=httpx.Timeout(15.0, connect=10.0)) as client:
        await asyncio.gather(*(eine(client, u) for u in reihenfolge(urls, alt, heute)))
    return stand


def bilder_pfad(katalog_pfad: str | Path) -> Path:
    return Path(katalog_pfad).with_name("bilder.json")


def lade_stand(pfad: Path) -> dict[str, dict]:
    if not pfad.exists():
        return {}
    return json.loads(pfad.read_text(encoding="utf-8"))


def stand_text(stand: dict[str, dict]) -> str:
    """Eine Adresse pro Zeile: Git speichert nachts nur die geänderten."""
    zeilen = [json.dumps(u, ensure_ascii=False) + ":" + json.dumps(stand[u], separators=(",", ":"))
              for u in sorted(stand)]
    return "{\n" + ",\n".join(zeilen) + ("\n" if zeilen else "") + "}\n"
