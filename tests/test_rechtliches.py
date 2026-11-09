"""Rechtstexte aus rechtliches/rechtliches.json als Webseiten (Plan 2026-11-05, Task 4)."""

import copy
import json

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


def _text(dokument_id: str) -> str:
    dokument = next(d for d in lade_texte()["dokumente"] if d["id"] == dokument_id)
    return " ".join(a for s in dokument["abschnitte"] for a in s["absaetze"])


def test_widerruf_verspricht_nur_was_die_app_haelt():
    # Statusabfrage beim Start und Produktfotos laufen auch ohne Zustimmung.
    text = _text("datenschutz")
    assert "schickt die App nichts mehr" not in text
    assert "Bevor zum ersten Mal etwas an den Server" not in text
    assert "keine Gespräche und keine Beschreibungen" in text


def test_gelerntes_geht_mit_den_wuenschen_mit():
    # Gewichtung.angewendet legt das beim Wischen Gelernte in die Wünsche, die zum Server gehen.
    text = _text("datenschutz")
    assert "alles Gelernte liegen nur auf deinem iPhone" not in text
    assert "Wünsche (mit dem, was die App beim Wischen gelernt hat)" in text


def test_reihenfolge_nennt_alle_hauptparameter():
    # § 5b Abs. 2 UWG: die Hauptparameter des Rankings, nicht nur einen Teil.
    text = _text("nutzung")
    assert "richtet sich nur danach" not in text
    for parameter in ("Abwechslung", "personalisier", "nach je zwei Produkten"):
        assert parameter in text, parameter


def test_app_texte_passen_zur_datenschutzerklaerung():
    from pathlib import Path
    ordner = Path(__file__).resolve().parents[1] / "ios" / "Geschenke"
    swift = "".join(p.read_text(encoding="utf-8") for p in ordner.glob("*.swift"))
    assert "schickt die App nichts mehr" not in swift
    assert "beim Wischen gelernt" in (ordner / "KiEinwilligungView.swift").read_text(encoding="utf-8")


def test_repo_enthaelt_nur_platzhalter():
    """Das Repo ist öffentlich: Name, Adresse und Telefon dürfen nie in rechtliches.json stehen."""
    from app.rechtliches import PFAD
    roh = json.loads(PFAD.read_text(encoding="utf-8"))
    assert sorted(offene_angaben(roh)) == sorted(roh["angaben"])


def test_impressum_aus_umgebung_ueberlagert_platzhalter():
    from app.rechtliches import mit_impressum
    texte = {"stand": "", "angaben": {"name": "[Vor- und Nachname]", "telefon": "[Telefonnummer]"}}
    echt = mit_impressum(texte, '{"name": "Max Muster", "fremd": "x"}')
    assert echt["angaben"] == {"name": "Max Muster", "telefon": "[Telefonnummer]"}
    assert texte["angaben"]["name"] == "[Vor- und Nachname]"  # Original bleibt unverändert
    assert mit_impressum(texte, "") is texte
