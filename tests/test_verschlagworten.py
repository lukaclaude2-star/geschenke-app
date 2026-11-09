import asyncio
import json

import pytest

from app.katalog import verschlagworten
from app.katalog.bauen import baue_katalog
from app.katalog.verschlagworten import inhalts_hash, verschlagworte
from app.modelle import QuellProdukt


def produkt(id: str, **abweichung) -> QuellProdukt:
    werte = dict(
        id=id, titel=f"Produkt {id}", beschreibung="Eine ausführliche Beschreibung " * 4,
        preis=25.0, bild_url="https://x/b.jpg", link=f"https://x/{id}", shop="Shop",
    )
    werte.update(abweichung)
    return QuellProdukt(**werte)


class FakeKi:
    """Antwortet je Produkt-id mit vorgegebenen Schlagwörtern; zählt Aufrufe."""

    def __init__(self, je_id: dict | None = None, standard: dict | None = None, auslassen=()):
        self.je_id = je_id or {}
        self.standard = standard or {"themen": ["garten"], "lebenslagen": [], "farben": [],
                                     "eigenschaften": [], "persoenlich": False, "note": 8}
        self.auslassen = set(auslassen)
        self.aufrufe = 0

    async def __call__(self, system: str, nutzer: str, **_):
        self.aufrufe += 1
        ids = [p["id"] for p in json.loads(nutzer)["produkte"]]
        return {"produkte": [
            {"id": i, **self.je_id.get(i, self.standard)} for i in ids if i not in self.auslassen
        ]}


@pytest.fixture
def ki(monkeypatch):
    fake = FakeKi()
    monkeypatch.setattr(verschlagworten, "frage_json", fake)
    return fake


async def test_unbekannte_themen_werden_verworfen(ki):
    ki.standard = {**ki.standard, "themen": ["garten", "quatsch"], "farben": ["kariert", "rot"],
                   "eigenschaften": ["alkohol", "nix"], "lebenslagen": ["rente", "mond"]}
    [p] = await verschlagworte([produkt("a")])
    assert (p.themen, p.farben, p.eigenschaften, p.lebenslagen) == (["garten"], ["rot"], ["alkohol"], ["rente"])


async def test_stichwort_mit_umlaut_oder_leerzeichen_wird_erkannt(ki):
    ki.standard = {**ki.standard, "themen": ["Einhörner", "Craft Beer", "Handwerk & DIY"]}
    [p] = await verschlagworte([produkt("a")])
    assert p.themen == ["einhoerner", "craft_beer"]


async def test_feed_farbe_landet_immer_in_farben(ki):
    [p] = await verschlagworte([produkt("a", farbe="Schwarz")])
    assert "schwarz" in p.farben


async def test_fehlendes_produkt_in_ki_antwort_wird_ausgelassen(ki):
    ki.auslassen = {"b"}
    ergebnis = await verschlagworte([produkt("a"), produkt("b")])
    assert [p.id for p in ergebnis] == ["a"]


async def test_stapel_zu_zwanzig(ki):
    await verschlagworte([produkt(str(i)) for i in range(43)])
    assert ki.aufrufe == 3


async def test_note_wird_auf_1_bis_10_begrenzt(ki):
    ki.standard = {**ki.standard, "note": 42}
    [p] = await verschlagworte([produkt("a")])
    assert p.note == 10


async def test_ki_ueberlastet_laesst_stapel_aus(monkeypatch):
    from app.ki import KiUeberlastet

    async def kaputt(*_, **__):
        raise KiUeberlastet()
    monkeypatch.setattr(verschlagworten, "frage_json", kaputt)
    assert await verschlagworte([produkt("a")]) == []


# --- Katalog-Bau -----------------------------------------------------------

@pytest.fixture
def ki_bau(monkeypatch):
    fake = FakeKi()
    monkeypatch.setattr(verschlagworten, "frage_json", fake)
    return fake


async def test_note_unter_6_wird_nicht_zeigbar(ki_bau):
    from app.katalog.laden import zeigbar
    ki_bau.je_id = {"schlecht": {**ki_bau.standard, "note": 5}}
    katalog, _ = await baue_katalog([produkt("gut"), produkt("schlecht")], [])
    assert [p.id for p in zeigbar(katalog)] == ["gut"]


async def test_abgelehntes_produkt_wird_nicht_neu_bewertet(ki_bau):
    ki_bau.je_id = {"schlecht": {**ki_bau.standard, "note": 2}}
    alt, _ = await baue_katalog([produkt("schlecht")], [])
    ki_bau.aufrufe = 0
    _, bericht = await baue_katalog([produkt("schlecht")], alt)
    assert ki_bau.aufrufe == 0 and bericht["note_raus"] == 1 and bericht["katalog"] == 0


async def test_unveraendertes_produkt_wird_nicht_neu_verschlagwortet(ki_bau):
    alt, _ = await baue_katalog([produkt("a")], [])
    ki_bau.aufrufe = 0
    katalog, _ = await baue_katalog([produkt("a")], alt)
    assert ki_bau.aufrufe == 0 and [p.id for p in katalog] == ["a"]


async def test_geaendertes_produkt_wird_neu_verschlagwortet(ki_bau):
    alt, _ = await baue_katalog([produkt("a")], [])
    ki_bau.aufrufe = 0
    await baue_katalog([produkt("a", preis=30.0)], alt)
    assert ki_bau.aufrufe == 1


async def test_regel_raus_wird_nicht_an_ki_geschickt(ki_bau):
    katalog, bericht = await baue_katalog([produkt("billig", preis=3.0)], [])
    assert ki_bau.aufrufe == 0 and katalog == [] and bericht["regel_raus"] == 1


async def test_bericht_zaehlt_richtig(ki_bau):
    alt, _ = await baue_katalog([produkt("alt")], [])
    ki_bau.je_id = {"mies": {**ki_bau.standard, "note": 2}}
    quellen = [produkt("alt"), produkt("neu"), produkt("mies"), produkt("billig", preis=1.0)]
    _, bericht = await baue_katalog(quellen, alt)
    assert bericht == {"quellen": 4, "regel_raus": 1, "wiederverwendet": 1,
                       "neu_verschlagwortet": 2, "noch_offen": 0, "note_raus": 1, "katalog": 2}


def test_lade_katalog_filtert_niedrige_noten(tmp_path):
    import json as _json
    from app.katalog.laden import lade_katalog
    from app.katalog.verschlagworten import inhalts_hash
    basis = produkt("a").model_dump()
    eintraege = [{**basis, "id": i, "themen": [], "lebenslagen": [], "farben": [], "eigenschaften": [],
                  "persoenlich": False, "note": n, "inhalts_hash": "h"} for i, n in (("gut", 7), ("mies", 3))]
    datei = tmp_path / "k.json"
    datei.write_text(_json.dumps(eintraege), encoding="utf-8")
    assert [p.id for p in lade_katalog(str(datei))] == ["gut"]


def test_inhalts_hash_aendert_sich_mit_preis():
    assert inhalts_hash(produkt("a")) != inhalts_hash(produkt("a", preis=99.0))


def test_lade_katalog_ohne_datei_ist_leer(tmp_path):
    from app.katalog.laden import lade_katalog
    assert lade_katalog(str(tmp_path / "fehlt.json")) == []


async def test_pause_zwischen_stapeln(ki, monkeypatch):
    pausen = []

    async def schlafen(sekunden):
        pausen.append(sekunden)
    monkeypatch.setattr(verschlagworten.asyncio, "sleep", schlafen)
    await verschlagworte([produkt(str(i)) for i in range(43)], pause_sekunden=7)
    assert pausen == [7, 7]


def test_inhalts_hash_haengt_an_vokabular_version(monkeypatch):
    import app.katalog.verschlagworten as v
    vorher = inhalts_hash(produkt("a"))
    monkeypatch.setattr(v, "VOKABULAR_VERSION", 999)
    assert inhalts_hash(produkt("a")) != vorher


async def test_alter_eintrag_bleibt_wenn_neu_verschlagworten_scheitert(ki_bau, monkeypatch):
    alt, _ = await baue_katalog([produkt("a"), produkt("b")], [])
    monkeypatch.setattr(verschlagworten, "VOKABULAR_VERSION", 999)  # alles muss neu
    ki_bau.auslassen = {"a"}  # Kontingent leer o. Ä.: "a" kommt nicht zurück
    katalog, bericht = await baue_katalog([produkt("a"), produkt("b")], alt)
    assert sorted(p.id for p in katalog) == ["a", "b"]
    alt_a = next(p for p in katalog if p.id == "a")
    assert alt_a.inhalts_hash != inhalts_hash(produkt("a"))  # wird beim nächsten Lauf erneut versucht
    assert bericht["noch_offen"] == 1


async def test_stoppt_nach_ueberlastung_und_bei_stapelgrenze(monkeypatch):
    from app.ki import KiUeberlastet
    aufrufe = 0

    async def ueberlastet(*_, **__):
        nonlocal aufrufe
        aufrufe += 1
        raise KiUeberlastet("Kontingent leer")
    monkeypatch.setattr(verschlagworten, "frage_json", ueberlastet)
    ergebnis = await verschlagworte([produkt(str(i)) for i in range(65)])
    assert ergebnis == [] and aufrufe == 1  # nicht noch 3 weitere Stapel gegen die Wand

    fake = FakeKi()
    monkeypatch.setattr(verschlagworten, "frage_json", fake)
    ergebnis = await verschlagworte([produkt(str(i)) for i in range(65)], max_stapel=2)
    assert len(ergebnis) == 40 and fake.aufrufe == 2


async def test_ganz_neue_produkte_zuerst(ki_bau):
    alt, _ = await baue_katalog([produkt("alt")], [])
    _, bericht = await baue_katalog([produkt("alt", preis=99.0), produkt("neu")], alt, max_stapel=1)
    assert bericht["neu_verschlagwortet"] == 2  # beide passen in einen Stapel
    reihenfolge = []

    async def merke(system, nutzer, **_):
        reihenfolge.extend(p["id"] for p in json.loads(nutzer)["produkte"])
        return {"produkte": []}
    import app.katalog.verschlagworten as v
    v.frage_json, vorher = merke, v.frage_json
    try:
        await baue_katalog([produkt("alt", preis=98.0), produkt("neu2")], alt)
    finally:
        v.frage_json = vorher
    assert reihenfolge == ["neu2", "alt"]


async def test_fehlende_note_bleibt_offen_statt_ramsch(ki):
    ki.je_id = {"ohne": {k: v for k, v in ki.standard.items() if k != "note"}}
    ergebnis = await verschlagworte([produkt("mit"), produkt("ohne")])
    assert [p.id for p in ergebnis] == ["mit"]  # „ohne“ kommt beim nächsten Lauf wieder dran


async def test_arbeiter_teilen_sich_die_stapel(monkeypatch):
    from app.ki import KiUeberlastet
    monkeypatch.setattr(verschlagworten, "WARTEN_NACH_UEBERLASTUNG", 0)
    je_modell: dict[str, int] = {}
    fake = FakeKi()

    async def ki(system, nutzer, modelle=None, **kw):
        [modell] = modelle
        if modell == "leer":
            raise KiUeberlastet()
        await asyncio.sleep(0)  # wie eine echte Netzanfrage: die anderen Arbeiter kommen dran
        je_modell[modell] = je_modell.get(modell, 0) + 1
        return await fake(system, nutzer)
    monkeypatch.setattr(verschlagworten, "frage_json", ki)
    ergebnis = await verschlagworte([produkt(str(i)) for i in range(200)],
                                    arbeiter={"a": 0, "b": 0, "leer": 0})
    assert len(ergebnis) == 200 and len({p.id for p in ergebnis}) == 200
    assert set(je_modell) == {"a", "b"} and sum(je_modell.values()) == 10


async def test_arbeiter_alle_leer_nichts_geht_verloren(monkeypatch):
    from app.ki import KiUeberlastet
    monkeypatch.setattr(verschlagworten, "WARTEN_NACH_UEBERLASTUNG", 0)

    async def leer(*_, **__):
        raise KiUeberlastet()
    monkeypatch.setattr(verschlagworten, "frage_json", leer)
    _, bericht = await baue_katalog([produkt(str(i)) for i in range(30)], [], arbeiter={"x": 0, "y": 0})
    assert bericht["noch_offen"] == 30


async def test_frist_abgelaufen_nimmt_keine_neuen_stapel(monkeypatch):
    """Damit GitHub den Lauf nicht vor dem Speichern abbricht: Nach der Frist bleibt der Rest offen."""
    aufrufe = []

    async def ki(*_, **__):
        aufrufe.append(1)
        raise AssertionError("nach der Frist keine Anfrage mehr")
    monkeypatch.setattr(verschlagworten, "frage_json", ki)
    _, bericht = await baue_katalog([produkt(str(i)) for i in range(30)], [],
                                    arbeiter={"x": 0, "y": 0}, frist_sekunden=0)
    assert bericht["noch_offen"] == 30 and aufrufe == []


async def test_frist_nicht_erreicht_schafft_alles(ki):
    _, bericht = await baue_katalog([produkt(str(i)) for i in range(30)], [],
                                    arbeiter={"x": 0, "y": 0}, frist_sekunden=3600)
    assert bericht["noch_offen"] == 0


def test_build_frist_aus_umgebung(monkeypatch):
    from scripts.build_katalog import frist_aus_umgebung
    monkeypatch.delenv("KATALOG_MAX_MINUTEN", raising=False)
    assert frist_aus_umgebung() is None
    monkeypatch.setenv("KATALOG_MAX_MINUTEN", "300")
    assert frist_aus_umgebung() == 18000
