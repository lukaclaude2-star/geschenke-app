"""Erkennt Partnerlinks, damit die App sie als „Anzeige“ kennzeichnet.

§ 5a Abs. 4 UWG und § 6 DDG: Ein Link, an dem wir Provision verdienen, muss direkt am Link als
Werbung erkennbar sein (Symbole reichen nicht, LG Berlin II 102 O 27/24). Normale Shop-Links
ohne Provision sind keine Werbung und bekommen kein Abzeichen.
"""

from urllib.parse import parse_qs, quote, urlsplit

from app.config import settings

# Tracking-Domains der Partnernetzwerke: ein Link dorthin ist immer ein Partnerlink.
NETZWERKE = (
    "awin1.com", "tradedoubler.com", "webgains.com", "adcell.com", "belboon.de",
    "financeads.net", "tradetracker.net", "prf.hn", "amzn.to",
)


def _host_gehoert_zu(host: str, domain: str) -> bool:
    return host == domain or host.endswith("." + domain)


def ist_partnerlink(link: str) -> bool:
    try:
        teile = urlsplit(link)
    except ValueError:
        return False
    host = (teile.hostname or "").lower()
    if not host:
        return False
    if any(_host_gehoert_zu(host, domain) for domain in NETZWERKE):
        return True
    # Amazon-Links verdienen nur mit Partner-Kennung („tag“).
    teil = host.split(".")
    ist_amazon = "amazon" in teil[:-1] and (teil[-2] == "amazon" or teil[-3:-1] == ["amazon", "co"])
    return ist_amazon and bool(parse_qs(teile.query).get("tag"))


def awin_programm_fuer(link: str, programme: dict[str, int]) -> int | None:
    """Awin-Programm-ID des Shops, zu dem der Link gehört (Schlüssel: Domain ohne „www.“)."""
    try:
        host = (urlsplit(link).hostname or "").lower()
    except ValueError:
        return None
    if not host:
        return None
    for domain, programm in programme.items():
        if _host_gehoert_zu(host, domain.lower().removeprefix("www.")):
            return programm
    return None


def awin_deeplink(link: str, programm: int, publisher_id: str) -> str:
    return (f"https://www.awin1.com/cread.php?awinmid={programm}&awinaffid={quote(publisher_id, safe='')}"
            f"&ued={quote(link, safe='')}")


def mit_partnerlink(link: str) -> str:
    """Normaler Shop-Link → Awin-Deeplink, wenn der Shop in AWIN_PROGRAMME steht und
    AWIN_PUBLISHER_ID gesetzt ist. Sonst bleibt der Link, wie er ist (Grundbaustein 2).

    Läuft beim Ausliefern der Karten, nicht beim Katalogbau: Ein neu angenommenes Programm
    wirkt sofort, sobald es in Render eingetragen ist – ohne Katalog-Lauf und App-Update."""
    if not settings.awin_publisher_id or not link or ist_partnerlink(link):
        return link
    programm = awin_programm_fuer(link, settings.awin_programme)
    return awin_deeplink(link, programm, settings.awin_publisher_id) if programm else link
