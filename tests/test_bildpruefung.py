import json
from datetime import date

import httpx

from app.katalog.bildpruefung import (KAPUTT, OK, UNKLAR, app_bild_url, bild_kaputt, faellig, ist_foto,
                                      lade_stand, neuer_eintrag, pruefe_bild, pruefe_bilder, reihenfolge,
                                      stand_text)

JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00"
PNG = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
WEBP = b"RIFF\x24\x00\x00\x00WEBPVP8 "
AVIF = b"\x00\x00\x00\x1cftypavif\x00\x00\x00\x00"
MP4 = b"\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00"
SVG = b'<svg xmlns="http://www.w3.org/2000/svg">'
HTML = b"<!DOCTYPE html><html><body>"
HEUTE = date(2026, 11, 23)


def _katalogprodukt(id: str, bild_url: str):
    from app.modelle import KatalogProdukt
    from tests.test_verschlagworten import produkt

    return KatalogProdukt(**produkt(id, bild_url=bild_url).model_dump(), themen=[], lebenslagen=[], farben=[],
                          eigenschaften=[], persoenlich=False, note=8, inhalts_hash="h")


def test_ist_foto_erkennt_was_das_iphone_zeigt():
    for foto in (JPEG, PNG, WEBP, AVIF, b"GIF89a\x01\x00\x01\x00\x00\x00\x00\x00"):
        assert ist_foto(foto)
    for kein_foto in (SVG, HTML, MP4, b""):
        assert not ist_foto(kein_foto)


def test_app_bild_url_macht_http_zu_https():
    assert app_bild_url("http://shop.de/a.jpg") == "https://shop.de/a.jpg"
    assert app_bild_url("https://shop.de/a.jpg") == "https://shop.de/a.jpg"


def test_app_bild_url_kodiert_leerzeichen_und_umlaute():
    assert app_bild_url("https://shop.de/Juni 2015/Gärtner.jpg") == "https://shop.de/Juni%202015/G%C3%A4rtner.jpg"
    # „a“ + kombinierendes Trema, wie bei einem Shop im Katalog
    assert app_bild_url("https://shop.de/Gärtner.jpg") == "https://shop.de/Ga%CC%88rtner.jpg"


def test_app_bild_url_ohne_bild():
    assert app_bild_url(None) is None
    assert app_bild_url("") == ""


def test_app_bild_url_laesst_gueltige_adressen_unveraendert():
    url = "https://cdn.shop.de/bild%20eins.jpg?w=800&format=webp"
    assert app_bild_url(url) == url


async def _pruefe(handler) -> str:
    async with httpx.AsyncClient(transport=httpx.MockTransport(handler), follow_redirects=True) as client:
        return await pruefe_bild(client, "https://shop.de/a.jpg")


async def test_pruefe_bild_foto_ist_ok():
    assert await _pruefe(lambda r: httpx.Response(200, content=JPEG)) == OK


async def test_pruefe_bild_ohne_content_type_zaehlt_inhalt():
    assert await _pruefe(lambda r: httpx.Response(200, content=PNG, headers={"content-type": "*/*"})) == OK


async def test_pruefe_bild_svg_und_html_sind_kaputt():
    assert await _pruefe(lambda r: httpx.Response(200, content=SVG)) == KAPUTT
    assert await _pruefe(lambda r: httpx.Response(200, content=HTML, headers={"content-type": "image/jpeg"})) == KAPUTT


async def test_pruefe_bild_toter_link_ist_kaputt():
    assert await _pruefe(lambda r: httpx.Response(404)) == KAPUTT
    assert await _pruefe(lambda r: httpx.Response(410)) == KAPUTT


async def test_pruefe_bild_sperre_und_ausfall_sind_unklar():
    assert await _pruefe(lambda r: httpx.Response(403)) == UNKLAR
    assert await _pruefe(lambda r: httpx.Response(503)) == UNKLAR

    def zeitueberschreitung(request):
        raise httpx.ConnectTimeout("zu langsam", request=request)

    assert await _pruefe(zeitueberschreitung) == UNKLAR


async def test_pruefe_bild_folgt_weiterleitung():
    def handler(request):
        if request.url.host == "shop.de":
            return httpx.Response(301, headers={"location": "https://cdn.shop.de/a.jpg"})
        return httpx.Response(200, content=JPEG)

    assert await _pruefe(handler) == OK


def test_unklar_wird_erst_nach_drei_fehlschlaegen_kaputt():
    eintrag = None
    for _ in range(2):
        eintrag = neuer_eintrag(eintrag, UNKLAR, HEUTE)
        assert not bild_kaputt(eintrag)
    eintrag = neuer_eintrag(eintrag, UNKLAR, HEUTE)
    assert eintrag["n"] == 3 and bild_kaputt(eintrag)
    assert not bild_kaputt(neuer_eintrag(eintrag, OK, HEUTE))


def test_kaputt_sofort_ungeprueft_nie():
    assert bild_kaputt(neuer_eintrag(None, KAPUTT, HEUTE))
    assert not bild_kaputt(None)


def test_faellig():
    assert faellig(None, HEUTE)
    assert faellig({"s": UNKLAR, "d": "2026-11-23", "n": 1}, HEUTE)
    assert not faellig({"s": OK, "d": "2026-11-20", "n": 0}, HEUTE)
    assert faellig({"s": OK, "d": "2026-11-09", "n": 0}, HEUTE)
    assert not faellig({"s": KAPUTT, "d": "2026-11-20", "n": 0}, HEUTE)
    assert faellig({"s": KAPUTT, "d": "2026-11-16", "n": 0}, HEUTE)


def test_reihenfolge_neue_zuerst_dann_aelteste():
    alt = {"b": {"s": OK, "d": "2026-10-01", "n": 0}, "c": {"s": OK, "d": "2026-09-01", "n": 0},
           "d": {"s": OK, "d": "2026-11-22", "n": 0}}
    assert reihenfolge(["b", "c", "d", "a"], alt, HEUTE) == ["a", "c", "b"]


async def test_pruefe_bilder_prueft_faellige_und_wirft_alte_adressen_raus():
    gesehen = []

    def handler(request):
        gesehen.append(str(request.url))
        return httpx.Response(200, content=SVG if "logo" in request.url.path else JPEG)

    alt = {"https://s.de/frisch.jpg": {"s": OK, "d": "2026-11-22", "n": 0},
           "https://s.de/weg.jpg": {"s": OK, "d": "2026-11-22", "n": 0}}
    urls = ["https://s.de/frisch.jpg", "https://s.de/neu.jpg", "https://s.de/logo.svg"]
    stand = await pruefe_bilder(urls, alt, HEUTE, transport=httpx.MockTransport(handler))
    assert sorted(gesehen) == ["https://s.de/logo.svg", "https://s.de/neu.jpg"]
    assert stand["https://s.de/neu.jpg"]["s"] == OK
    assert stand["https://s.de/logo.svg"]["s"] == KAPUTT
    assert stand["https://s.de/frisch.jpg"] == alt["https://s.de/frisch.jpg"]
    assert "https://s.de/weg.jpg" not in stand


async def test_pruefe_bilder_hoert_nach_frist_auf():
    stand = await pruefe_bilder(["https://s.de/a.jpg"], {}, HEUTE, frist_sekunden=-1,
                                transport=httpx.MockTransport(lambda r: httpx.Response(200, content=JPEG)))
    assert stand == {}


def test_stand_text_ist_gueltiges_json(tmp_path):
    stand = {"https://s.de/b.jpg": {"s": OK, "d": "2026-11-23", "n": 0},
             "https://s.de/ä.jpg": {"s": UNKLAR, "d": "2026-11-23", "n": 1}}
    datei = tmp_path / "bilder.json"
    datei.write_text(stand_text(stand), encoding="utf-8")
    assert lade_stand(datei) == stand
    assert len(datei.read_text(encoding="utf-8").splitlines()) == 4
    assert lade_stand(tmp_path / "fehlt.json") == {}


def test_lade_katalog_laesst_produkte_mit_kaputtem_bild_weg(tmp_path):
    from app.katalog.laden import lade_katalog

    katalog = tmp_path / "katalog.json"
    produkte = [_katalogprodukt("gut", bild_url="https://s.de/gut.jpg"),
                _katalogprodukt("kaputt", bild_url="http://s.de/kaputt.jpg"),
                _katalogprodukt("ungeprueft", bild_url="https://s.de/neu.jpg")]
    katalog.write_text(json.dumps([p.model_dump() for p in produkte]), encoding="utf-8")
    (tmp_path / "bilder.json").write_text(stand_text({
        "https://s.de/gut.jpg": {"s": OK, "d": "2026-11-23", "n": 0},
        "https://s.de/kaputt.jpg": {"s": KAPUTT, "d": "2026-11-23", "n": 0},
    }), encoding="utf-8")
    assert [p.id for p in lade_katalog(str(katalog))] == ["gut", "ungeprueft"]


def test_karte_bekommt_app_taugliche_bildadresse():
    from app.karten import produkt_zu_karte

    karte = produkt_zu_karte(_katalogprodukt("a", bild_url="http://s.de/Juni 2015/a.jpg"))
    assert karte.bild_url == "https://s.de/Juni%202015/a.jpg"
