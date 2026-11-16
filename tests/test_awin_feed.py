"""Awin-Feeds werden zu Quellprodukten (Vorbereitung für die Zeit nach der Annahme bei Awin)."""

import gzip
import io
import zipfile

from app.katalog.awin import feed_text, produkte_aus_feed
from app.katalog.regeln import pruefe_regeln
from app.partnerlinks import ist_partnerlink

BESCHREIBUNG = "Ein Abend im Kochkurs mit Profi-Koch, drei Gängen und Weinbegleitung für zwei Personen."

# Legacy-Download für Publisher (Komma, Spalten wie in Awins Create-a-Feed).
LEGACY = (
    "aw_deep_link,product_name,aw_product_id,merchant_product_id,merchant_image_url,description,"
    "merchant_category,search_price,merchant_name,aw_image_url,currency,in_stock,colour\n"
    f'"https://www.awin1.com/cread.php?awinmid=1&awinaffid=2&ued=https%3A%2F%2Fmydays.de%2Fk",'
    f'Kochkurs für zwei,111,K-1,https://img.mydays.de/gross.jpg,"{BESCHREIBUNG}",Kochen,89.90,mydays,'
    f"https://images2.productserve.com/klein.jpg,EUR,1,\n"
    f'"https://www.awin1.com/cread.php?awinmid=1&awinaffid=2&ued=x",Ausverkauft,112,K-2,'
    f'https://img.mydays.de/a.jpg,"{BESCHREIBUNG}",Kochen,50,mydays,,EUR,0,\n'
)

# Enhanced (Google-Format) mit Semikolon und deutschem Preis.
ENHANCED = (
    "id;title;description;link;aw_deep_link;image_link;availability;price;brand;color;item_group_id\n"
    f"E-1;Rotes Halstuch;{BESCHREIBUNG};https://shop.de/h;"
    "https://www.awin1.com/cread.php?awinmid=5&awinaffid=2&ued=https%3A%2F%2Fshop.de%2Fh;"
    "https://shop.de/h.jpg;in_stock;19,99 EUR;Marke;rot;G-1\n"
    f"E-2;Blaues Halstuch;{BESCHREIBUNG};https://shop.de/b;;https://shop.de/b.jpg;out_of_stock;19,99 EUR;"
    "Marke;blau;G-1\n"
)


def test_legacy_feed():
    produkte = produkte_aus_feed(LEGACY)
    assert [p.id for p in produkte] == ["awin-111", "awin-112"]
    p = produkte[0]
    assert p.titel == "Kochkurs für zwei"
    assert p.preis == 89.90
    assert p.shop == "mydays"
    assert p.bild_url == "https://img.mydays.de/gross.jpg"  # großes Händlerbild statt Vorschau
    assert p.kategorie == "Kochen"
    assert ist_partnerlink(p.link)
    assert pruefe_regeln(p) is None
    assert produkte[1].lieferbar is False
    assert pruefe_regeln(produkte[1]) == "nicht lieferbar"


def test_enhanced_feed_mit_semikolon():
    produkte = produkte_aus_feed(ENHANCED, shop="Halstuch-Shop")
    p, ausverkauft = produkte
    assert p.link.startswith("https://www.awin1.com/")  # verfolgter Link vor dem normalen
    assert ausverkauft.link == "https://shop.de/b"  # ohne aw_deep_link: normaler Link (Umbau zur Laufzeit)
    assert p.preis == 19.99
    assert p.shop == "Halstuch-Shop"
    assert p.farbe == "rot"
    assert p.varianten_gruppe == "G-1"
    assert ausverkauft.lieferbar is False


def test_zeilen_ohne_pflichtangaben_oder_fremdwaehrung_fallen_weg():
    feed = (
        "aw_deep_link,product_name,aw_product_id,search_price,currency\n"
        "https://www.awin1.com/c,,1,10,EUR\n"  # kein Titel
        "https://www.awin1.com/c,Ding,2,,EUR\n"  # kein Preis
        "https://www.awin1.com/c,Ding,3,10,GBP\n"  # andere Währung
        "http://unsicher.de/c,Ding,4,10,EUR\n"  # kein https
        "https://www.awin1.com/c,Ding,5,10,EUR\n"
        "https://www.awin1.com/c,Ding doppelt,5,10,EUR\n"
    )
    assert [p.id for p in produkte_aus_feed(feed)] == ["awin-5"]


def test_feed_text_entpackt_gzip_zip_und_bom():
    roh = "﻿a,b\n1,2\n".encode("utf-8")
    assert feed_text(roh) == "a,b\n1,2\n"
    assert feed_text(gzip.compress(roh)) == "a,b\n1,2\n"
    puffer = io.BytesIO()
    with zipfile.ZipFile(puffer, "w") as archiv:
        archiv.writestr("feed.csv", roh)
    assert feed_text(puffer.getvalue()) == "a,b\n1,2\n"


def test_leerer_feed():
    assert produkte_aus_feed("") == []
