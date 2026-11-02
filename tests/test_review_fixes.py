"""Regressionstests aus der Abschlussprüfung (C1, I1, I2, I3, I8)."""

import json

import pytest

from app import ideen as ideen_modul
from app import profil as profil_modul
from app.ideen import ideen_karten
from app.katalog import verschlagworten
from app.katalog.verschlagworten import verschlagworte
from app.modelle import Ausschluss, KatalogProdukt, Profil, QuellProdukt, Wunsch
from app.profil import SYSTEM_AUS_GESPRAECH, bereinige_profil, profil_aendern
from app.ranking import ist_ausgeschlossen


def produkt(titel="Produkt", beschreibung="Beschreibung", themen=("erlebnis",), **rest) -> KatalogProdukt:
    werte = dict(id="p", titel=titel, beschreibung=beschreibung, preis=30.0, bild_url="https://x/b.jpg",
                 link="https://x/p", shop="Shop", themen=list(themen), lebenslagen=[], farben=[],
                 eigenschaften=[], persoenlich=False, note=8, inhalts_hash="h")
    werte.update(rest)
    return KatalogProdukt(**werte)


def aus(*s):
    return [Ausschluss(schluessel=x, label=x) for x in s]


# C1: Eigenschaften auch über den Text --------------------------------------

def test_alkohol_im_text_wird_ausgeschlossen_auch_ohne_tag():
    p = produkt("Paint & Drink München", "Malen bei Wein und Leinwand, Acrylfarben, Utensilien und Wein inklusive")
    assert ist_ausgeschlossen(p, aus("eigenschaft:alkohol"))


def test_aperitif_und_sekt_werden_erkannt():
    assert ist_ausgeschlossen(produkt(beschreibung="inklusive kostenlosem Aperitif"), aus("eigenschaft:alkohol"))
    assert ist_ausgeschlossen(produkt(beschreibung="Ein Glas Sekt zur Begrüßung"), aus("eigenschaft:alkohol"))


def test_alkohol_trifft_keine_harmlosen_woerter():
    p = produkt("Rundflug über Berlin", "Ein Erlebnis mit Ginkgo-Allee und Weihnachtsmarkt")
    assert not ist_ausgeschlossen(p, aus("eigenschaft:alkohol"))


def test_suessigkeiten_im_text():
    assert ist_ausgeschlossen(produkt("Pralinen-Workshop"), aus("eigenschaft:suessigkeiten"))


# I1: thema: prüft auch den Text --------------------------------------------

def test_thema_katze_schliesst_katzen_motiv_aus():
    profil = bereinige_profil({"zusammenfassung": "x", "wuensche": [], "ausschluesse": ["thema:katze"]})
    p = produkt("Tasse mit Katzen-Motiv", themen=["kaffee"])
    assert ist_ausgeschlossen(p, profil.ausschluesse)


# C1 + M8: Ideen liefern Eigenschaften, Farben, Lebenslagen ------------------

IDEE = {"titel": "Weinkühler mit Gravur", "emoji": "🍾", "preis_von": 20, "preis_bis": 30,
        "suchbegriff": "Weinkühler Gravur", "themen": ["wohnen"]}


@pytest.fixture
def ideen_ki(monkeypatch):
    antworten = {"ideen": [IDEE]}

    async def ki(*_, **__):
        return antworten
    monkeypatch.setattr(ideen_modul, "frage_json", ki)
    return antworten


def profil_mit(*ausschluesse, budget=None) -> Profil:
    return Profil(zusammenfassung="x", wuensche=[Wunsch(tag="wohnen", label="w", gewicht=1.0)],
                  ausschluesse=aus(*ausschluesse), budget_max=budget)


async def test_idee_mit_alkohol_wort_wird_verworfen(ideen_ki):
    assert await ideen_karten(profil_mit("eigenschaft:alkohol"), 5, set()) == []


async def test_idee_eigenschaft_aus_ki_wird_geprueft(ideen_ki):
    ideen_ki["ideen"] = [{**IDEE, "titel": "Geschenkkorb", "suchbegriff": "Geschenkkorb",
                          "eigenschaften": ["suessigkeiten"]}]
    assert await ideen_karten(profil_mit("eigenschaft:suessigkeiten"), 5, set()) == []


async def test_idee_lebenslage_ausschluss(ideen_ki):
    ideen_ki["ideen"] = [{**IDEE, "titel": "Hochzeitsalbum", "suchbegriff": "Album",
                          "lebenslagen": ["hochzeit"]}]
    assert await ideen_karten(profil_mit("thema:hochzeit"), 5, set()) == []


# I2: Profil ändern verliert nichts -----------------------------------------

ALT = Profil(zusammenfassung="Oma, gärtnert",
             wuensche=[Wunsch(tag="garten", label="g", gewicht=1.2), Wunsch(tag="krimis", label="k", gewicht=1.0)],
             ausschluesse=aus("farbe:schwarz", "eigenschaft:alkohol"), budget_max=50.0)


def ki_antwortet(monkeypatch, antwort: dict):
    async def ki(*_, **__):
        return antwort
    monkeypatch.setattr(profil_modul, "frage_json", ki)


async def test_aendern_mit_leerer_antwort_behaelt_alles(monkeypatch):
    ki_antwortet(monkeypatch, {})
    neu = await profil_aendern(ALT, "sie hat jetzt einen Hund")
    assert [a.schluessel for a in neu.ausschluesse] == ["farbe:schwarz", "eigenschaft:alkohol"]
    assert neu.budget_max == 50.0 and [w.tag for w in neu.wuensche] == ["garten", "krimis"]


async def test_aendern_fuegt_hinzu_und_entfernt_gezielt(monkeypatch):
    ki_antwortet(monkeypatch, {"neue_wuensche": [{"tag": "hund", "gewicht": 1.3}],
                               "entfernte_wuensche": ["krimis"],
                               "entfernte_ausschluesse": ["farbe:schwarz"],
                               "neue_ausschluesse": ["wort:katze"]})
    neu = await profil_aendern(ALT, "Hund statt Krimis, Schwarz ist jetzt okay, keine Katzen")
    assert [(w.tag, w.gewicht) for w in neu.wuensche] == [("garten", 1.2), ("hund", 1.3)]
    assert [a.schluessel for a in neu.ausschluesse] == ["eigenschaft:alkohol", "wort:katze"]


async def test_aendern_budget_nur_wenn_genannt(monkeypatch):
    ki_antwortet(monkeypatch, {"budget_max": 80})
    assert (await profil_aendern(ALT, "jetzt bis 80 €")).budget_max == 80.0
    ki_antwortet(monkeypatch, {"budget_max": None})
    assert (await profil_aendern(ALT, "Budget egal")).budget_max is None


async def test_aendern_gewicht_bestehender_wunsch(monkeypatch):
    ki_antwortet(monkeypatch, {"neue_wuensche": [{"tag": "garten", "gewicht": 1.8}]})
    neu = await profil_aendern(ALT, "Garten ist ihr ganz wichtig")
    assert [(w.tag, w.gewicht) for w in neu.wuensche][0] == ("garten", 1.8)


# I3: falsche Typen in gültigem JSON stürzen nicht ab -------------------------

def test_bereinigen_mit_falschen_typen():
    p = bereinige_profil({"zusammenfassung": 5, "wuensche": [{"tag": ["garten"]}, "x", {"tag": "garten"}],
                          "ausschluesse": {"a": 1}, "budget_max": [1]})
    assert [w.tag for w in p.wuensche] == ["garten"] and p.ausschluesse == [] and p.budget_max is None


def test_bereinigen_wuensche_kein_array():
    assert bereinige_profil({"wuensche": 5}).wuensche == []


async def test_ideen_kein_array(ideen_ki):
    ideen_ki["ideen"] = 5
    assert await ideen_karten(profil_mit(), 5, set()) == []


async def test_ideen_themen_kein_array(ideen_ki):
    ideen_ki["ideen"] = [{**IDEE, "themen": 5, "eigenschaften": 3, "lebenslagen": "x"}]
    karten = await ideen_karten(profil_mit(), 5, set())
    assert len(karten) == 1 and karten[0].tags == []


async def test_verschlagworten_id_als_liste(monkeypatch):
    async def ki(*_, **__):
        return {"produkte": [{"id": ["a"]}, {"id": "a", "themen": "garten", "note": "9"}]}
    monkeypatch.setattr(verschlagworten, "frage_json", ki)
    q = QuellProdukt(id="a", titel="t", beschreibung="b" * 80, preis=20.0, bild_url="https://x", link="https://x", shop="s")
    [p] = await verschlagworte([q])
    assert p.themen == [] and p.note == 9


# I8: keine Beispielwerte im JSON-Gerüst -------------------------------------

def test_prompt_geruest_ohne_echte_beispielwerte():
    geruest = SYSTEM_AUS_GESPRAECH.split("Erlaubte")[0]
    assert "farbe:schwarz" not in geruest and "eigenschaft:alkohol" not in geruest
