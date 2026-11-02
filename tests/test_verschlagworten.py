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


async def test_feed_farbe_landet_immer_in_farben(ki):
    [p] = await verschlagworte([produkt("a", farbe="Schwarz")])
    assert "schwarz" in p.farben


async def test_fehlendes_produkt_in_ki_antwort_wird_ausgelassen(ki):
    ki.auslassen = {"b"}
    ergebnis = await verschlagworte([produkt("a"), produkt("b")])
    assert [p.id for p in ergebnis] == ["a"]


async def test_stapel_zu_zehn(ki):
    await verschlagworte([produkt(str(i)) for i in range(23)])
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


async def test_note_unter_6_fliegt_raus(ki_bau):
    ki_bau.je_id = {"schlecht": {**ki_bau.standard, "note": 5}}
    katalog, _ = await baue_katalog([produkt("gut"), produkt("schlecht")], [])
    assert [p.id for p in katalog] == ["gut"]


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
                       "neu_verschlagwortet": 2, "note_raus": 1, "katalog": 2}


def test_inhalts_hash_aendert_sich_mit_preis():
    assert inhalts_hash(produkt("a")) != inhalts_hash(produkt("a", preis=99.0))


def test_lade_katalog_ohne_datei_ist_leer(tmp_path):
    from app.katalog.laden import lade_katalog
    assert lade_katalog(str(tmp_path / "fehlt.json")) == []
