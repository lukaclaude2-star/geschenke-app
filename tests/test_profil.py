import json

import pytest

from app import profil as profil_modul
from app.ki import KiUeberlastet
from app.modelle import Ausschluss, ChatNachricht, Profil, Wunsch
from app.profil import bereinige_profil, profil_aendern, profil_aus_gespraech
from app.vokabular import THEMEN


def roh(**abweichung) -> dict:
    werte = {
        "zusammenfassung": "Oma, gärtnert gern",
        "wuensche": [{"tag": "garten", "gewicht": 1.2}],
        "ausschluesse": ["farbe:schwarz"],
        "budget_max": 50,
    }
    werte.update(abweichung)
    return werte


def test_bereinigen_verwirft_unbekannte_tags():
    p = bereinige_profil(roh(wuensche=[{"tag": "garten", "gewicht": 1}, {"tag": "quatsch", "gewicht": 1}]))
    assert [w.tag for w in p.wuensche] == ["garten"]


def test_bereinigen_klemmt_gewichte_und_setzt_standard():
    p = bereinige_profil(roh(wuensche=[{"tag": "garten", "gewicht": 9}, {"tag": "krimis", "gewicht": -1},
                                       {"tag": "lesen"}]))
    assert [w.gewicht for w in p.wuensche] == [2.0, 0.0, 1.0]


def test_bereinigen_doppelte_tags_hoeheres_gewicht():
    p = bereinige_profil(roh(wuensche=[{"tag": "garten", "gewicht": 0.5}, {"tag": "garten", "gewicht": 1.4}]))
    assert [(w.tag, w.gewicht) for w in p.wuensche] == [("garten", 1.4)]


def test_bereinigen_verwirft_ungueltige_ausschluesse():
    p = bereinige_profil(roh(ausschluesse=["farbe:schwarz", "farbe:kariert", "unsinn", 5]))
    assert [a.schluessel for a in p.ausschluesse] == ["farbe:schwarz"]


def test_bereinigen_akzeptiert_ausschluss_objekte():
    p = bereinige_profil(roh(ausschluesse=[{"schluessel": "wort:katze", "label": "egal"}]))
    assert p.ausschluesse == [Ausschluss(schluessel="wort:katze", label="„katze“")]


def test_bereinigen_setzt_labels():
    p = bereinige_profil(roh())
    assert p.wuensche[0].label == THEMEN["garten"]
    assert p.ausschluesse[0].label == "Schwarz"


def test_bereinigen_budget_ungueltig_wird_none():
    assert bereinige_profil(roh(budget_max="viel")).budget_max is None
    assert bereinige_profil(roh(budget_max=0)).budget_max is None


async def test_aus_gespraech_nutzt_ki_und_bereinigt(monkeypatch):
    gesehen = {}

    async def ki(system, nutzer, **_):
        gesehen["nutzer"] = nutzer
        return roh(wuensche=[{"tag": "garten", "gewicht": 1}, {"tag": "mond", "gewicht": 1}])
    monkeypatch.setattr(profil_modul, "frage_json", ki)
    p = await profil_aus_gespraech([ChatNachricht(rolle="nutzer", text="Oma mag Garten")])
    assert "Oma mag Garten" in gesehen["nutzer"]
    assert [w.tag for w in p.wuensche] == ["garten"]


async def test_aendern_schickt_altes_profil_und_anweisung_mit(monkeypatch):
    gesehen = {}

    async def ki(system, nutzer, **_):
        gesehen["nutzer"] = nutzer
        return {"neue_wuensche": [{"tag": "hund", "gewicht": 1}]}
    monkeypatch.setattr(profil_modul, "frage_json", ki)
    alt = Profil(zusammenfassung="Oma", wuensche=[Wunsch(tag="garten", label="x", gewicht=1.0)],
                 ausschluesse=[], budget_max=None)
    neu = await profil_aendern(alt, "sie hat jetzt einen Hund")
    daten = json.loads(gesehen["nutzer"])
    assert daten["anweisung"] == "sie hat jetzt einen Hund"
    assert daten["profil"]["wuensche"][0]["tag"] == "garten"
    assert [w.tag for w in neu.wuensche] == ["garten", "hund"]


def test_ki_ueberlastet_gibt_503(client, auth, monkeypatch):
    async def kaputt(*_, **__):
        raise KiUeberlastet()
    monkeypatch.setattr(profil_modul, "frage_json", kaputt)
    r = client.post("/profil/aus-gespraech", json={"nachrichten": []}, headers=auth)
    assert r.status_code == 503 and r.json() == {"fehler": "ki_ueberlastet"}


def test_profil_routen_brauchen_token(client):
    assert client.post("/profil/aus-gespraech", json={"nachrichten": []}).status_code == 401
    assert client.post("/profil/aendern", json={}).status_code == 401
