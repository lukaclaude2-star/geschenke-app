"""Server-Härtung vor dem App-Store-Start: Grenzen, Header, Logs (Plan 2026-11-05, Task 1)."""

import logging

import httpx
import pytest
import respx
from pydantic import ValidationError

from app.ki import GROQ_URL, KiUeberlastet, frage_json
from app.modelle import (Ausschluss, ChatNachricht, KartenAnfrage, Profil, ProfilAendernAnfrage,
                         SammelPerson, Wunsch)


def profil() -> Profil:
    return Profil(zusammenfassung="Oma", wuensche=[Wunsch(tag="garten", label="Garten", gewicht=1.0)],
                  ausschluesse=[])


def test_langer_chattext_wird_gekuerzt():
    assert ChatNachricht(rolle="nutzer", text="a" * 5000).text == "a" * 2000


def test_lange_anweisung_wird_gekuerzt():
    assert len(ProfilAendernAnfrage(profil=profil(), anweisung="b" * 5000).anweisung) == 2000


def test_lange_zusammenfassung_wird_gekuerzt():
    p = Profil(zusammenfassung="c" * 5000, wuensche=[], ausschluesse=[])
    assert len(p.zusammenfassung) == 2000


def test_gesehen_behaelt_die_letzten():
    gesehen = [str(i) for i in range(12_000)]
    anfrage = KartenAnfrage(profil=profil(), gesehen=gesehen)
    assert len(anfrage.gesehen) == 10_000
    assert anfrage.gesehen[0] == "2000"
    person = SammelPerson(id="0", profil=profil(), gesehen=gesehen)
    assert len(person.gesehen) == 10_000
    assert person.gesehen[-1] == "11999"


def test_doppelte_ausschluesse_fallen_weg():
    # Wiederholte Ausschlüsse kosten bei jedem Produkt Rechenzeit, sagen aber nichts Neues.
    gleich = [{"schluessel": "eigenschaft:alkohol", "label": "kein Alkohol"}] * 1000
    p = Profil(zusammenfassung="x", wuensche=[], ausschluesse=gleich)
    assert [a.schluessel for a in p.ausschluesse] == ["eigenschaft:alkohol"]


def test_zu_viele_ausschluesse_abgelehnt():
    # Kürzen hieße, einen Ausschluss stillschweigend zu ignorieren (Grundbaustein 3).
    viele = [{"schluessel": f"wort:w{i}", "label": "x"} for i in range(31)]
    with pytest.raises(ValidationError):
        Profil(zusammenfassung="x", wuensche=[], ausschluesse=viele)
    assert len(Profil(zusammenfassung="x", wuensche=[], ausschluesse=viele[:30]).ausschluesse) == 30


def test_zu_langer_ausschluss_abgelehnt():
    with pytest.raises(ValidationError):
        Ausschluss(schluessel="wort:" + "a" * 300, label="x")


def test_wuensche_behalten_die_staerksten():
    wuensche = [{"tag": f"t{i}", "label": "x", "gewicht": i / 100} for i in range(150)]
    p = Profil(zusammenfassung="x", wuensche=wuensche, ausschluesse=[])
    assert [w.tag for w in p.wuensche] == [f"t{i}" for i in range(50, 150)]


def test_kaputtes_gewicht_wird_validierungsfehler():
    kaputt = [{"tag": f"t{i}", "label": "x", "gewicht": "viel"} for i in range(101)]
    with pytest.raises(ValidationError):
        Profil(zusammenfassung="x", wuensche=kaputt, ausschluesse=[])


def test_kurze_felder_gekuerzt():
    w = Wunsch(tag="t" * 500, label="l" * 500, gewicht=1)
    assert (len(w.tag), len(w.label)) == (100, 100)
    assert len(Ausschluss(schluessel="wort:bier", label="l" * 500).label) == 100


def test_zu_viele_nachrichten_abgelehnt(client, auth):
    nachrichten = [{"rolle": "nutzer", "text": "x"}] * 61
    antwort = client.post("/chat/naechste", json={"laenge": "normal", "nachrichten": nachrichten},
                          headers=auth)
    assert antwort.status_code == 422


def test_zu_grosse_anfrage(client, auth):
    antwort = client.post("/chat/naechste", content=b"{}",
                          headers={**auth, "Content-Type": "application/json", "Content-Length": "4000001"})
    assert antwort.status_code == 413


def test_post_ohne_laenge(client, auth):
    def stueckweise():
        yield b'{"laenge": "normal", "nachrichten": []}'

    antwort = client.post("/chat/naechste", content=stueckweise(),
                          headers={**auth, "Content-Type": "application/json"})
    assert antwort.status_code == 411


def test_docs_aus(client):
    for pfad in ("/docs", "/redoc", "/openapi.json"):
        assert client.get(pfad).status_code == 404, pfad


def test_sicherheits_header(client):
    kopf = client.get("/health").headers
    assert kopf["x-content-type-options"] == "nosniff"
    assert kopf["referrer-policy"] == "no-referrer"
    assert kopf["x-frame-options"] == "DENY"
    assert "max-age=" in kopf["strict-transport-security"]


@respx.mock
async def test_log_ohne_ki_text(caplog):
    kaputt = httpx.Response(200, json={"choices": [{"message": {"content": "Oma mag Rosen, kein json"}}]})
    respx.post(GROQ_URL).mock(return_value=kaputt)
    with caplog.at_level(logging.WARNING):
        try:
            await frage_json("sys", "nutzer")
        except KiUeberlastet:
            pass
    assert caplog.records
    assert "Oma" not in caplog.text


@respx.mock
async def test_log_bei_fehlerstatus_ohne_inhalt(caplog):
    fehler = httpx.Response(400, json={"error": {"code": "json_validate_failed",
                                                 "failed_generation": "Oma mag Rosen"}})
    respx.post(GROQ_URL).mock(return_value=fehler)
    with caplog.at_level(logging.WARNING):
        try:
            await frage_json("sys", "nutzer")
        except KiUeberlastet:
            pass
    assert "json_validate_failed" in caplog.text
    assert "Oma" not in caplog.text
