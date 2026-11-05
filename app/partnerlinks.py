"""Erkennt Partnerlinks, damit die App sie als „Anzeige“ kennzeichnet.

§ 5a Abs. 4 UWG und § 6 DDG: Ein Link, an dem wir Provision verdienen, muss direkt am Link als
Werbung erkennbar sein (Symbole reichen nicht, LG Berlin II 102 O 27/24). Normale Shop-Links
ohne Provision sind keine Werbung und bekommen kein Abzeichen.
"""

from urllib.parse import parse_qs, urlsplit

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
