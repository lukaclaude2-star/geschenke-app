"""Rechtstexte aus rechtliches/rechtliches.json als Webseiten (Plan 2026-11-05, Task 4)."""

import copy

import pytest

from app.rechtliches import (DOKUMENTE, ausfuellen, inline_html, lade_texte, offene_angaben, seite)

ROUTEN = {"/impressum": "Impressum", "/datenschutz": "Datenschutzerklärung",
          "/nutzung": "So entstehen die Vorschläge", "/support": "Hilfe und Kontakt",
          "/lizenzen": "Lizenzen"}


@pytest.mark.parametrize("pfad,titel", ROUTEN.items())
def test_seite_ohne_token_erreichbar(client, pfad, titel):
    antwort = client.get(pfad)
    assert antwort.status_code == 200
    assert antwort.headers["content-type"].startswith("text/html")
    assert titel in antwort.text
    assert "{{" not in antwort.text
    assert "default-src 'none'" in antwort.headers["content-security-policy"]


def test_alle_dokumente_vorhanden():
    texte = lade_texte()
    ids = [d["id"] for d in texte["dokumente"]]
    assert sorted(ids) == sorted(DOKUMENTE)
    for dokument in texte["dokumente"]:
        assert dokument["abschnitte"], dokument["id"]
        for abschnitt in dokument["abschnitte"]:
            assert abschnitt["absaetze"], (dokument["id"], abschnitt.get("ueberschrift"))


def test_datenschutz_nennt_dienste_und_rechte(client):
    text = client.get("/datenschutz").text
    for pflicht in ("Groq", "Render", "Frankfurt", "Art. 6 Abs. 1 lit. b", "Art. 6 Abs. 1 lit. f",
                    "widerrufen", "Beschwerde", "IP-Adresse", "Alle Daten löschen"):
        assert pflicht in text, pflicht


def test_impressum_nach_ddg(client):
    text = client.get("/impressum").text
    assert "§ 5 DDG" in text
    assert "Verbraucherschlichtungsstelle" in text


def test_nutzung_erklaert_reihenfolge_und_anzeige(client):
    text = client.get("/nutzung").text
    for pflicht in ("Provision", "Anzeige", "Reihenfolge", "MwSt.", "Versand", "KI"):
        assert pflicht in text, pflicht


def test_platzhalter_aus_angaben():
    texte = {"stand": "05.11.2026", "angaben": {"name": "Max Muster"}}
    assert ausfuellen("Hallo {{name}}, Stand {{stand}}", texte) == "Hallo Max Muster, Stand 05.11.2026"


def test_unbekannter_platzhalter_bleibt_sichtbar():
    assert ausfuellen("{{gibtsnicht}}", {"stand": "", "angaben": {}}) == "{{gibtsnicht}}"


def test_html_wird_escaped():
    assert inline_html("<script>alert(1)</script>") == "&lt;script&gt;alert(1)&lt;/script&gt;"


def test_fett_und_links():
    assert inline_html("**wichtig**") == "<strong>wichtig</strong>"
    assert inline_html("[Mail](mailto:a@b.de)") == '<a href="mailto:a@b.de">Mail</a>'
    assert inline_html("[Seite](https://x.de/a?b=1&c=2)") == '<a href="https://x.de/a?b=1&amp;c=2">Seite</a>'


def test_gefaehrlicher_link_wird_kein_link():
    html = inline_html("[x](javascript:alert(1))")
    assert "<a" not in html


def test_link_mit_anfuehrungszeichen_bricht_nicht_aus():
    html = inline_html('[x](https://x.de/"onmouseover="alert(1))')
    assert 'onmouseover="' not in html


def test_offene_angaben_meldet_platzhalter():
    texte = lade_texte()
    roh = copy.deepcopy(texte)
    roh["angaben"] = {"name": "[Vor- und Nachname]", "email": "luka@example.org"}
    assert offene_angaben(roh) == ["name"]


def test_seite_unbekannt():
    assert seite("gibtsnicht") is None


def test_listenpunkte():
    texte = {"stand": "", "angaben": {}, "dokumente": [
        {"id": "impressum", "titel": "T", "abschnitte": [{"ueberschrift": None, "absaetze": ["- eins", "- zwei", "Text"]}]}]}
    html = seite("impressum", texte)
    assert "<ul><li>eins</li><li>zwei</li></ul>" in html
    assert "<p>Text</p>" in html
