import json
from pathlib import Path

from app.katalog.regeln import pruefe_regeln
from app.modelle import QuellProdukt

QUELLEN = Path(__file__).resolve().parent.parent / "katalog" / "quellen"


def lade() -> list[QuellProdukt]:
    return [QuellProdukt(**e) for datei in sorted(QUELLEN.glob("*.json"))
            for e in json.loads(datei.read_text(encoding="utf-8"))]


def test_mindestens_120_eindeutige_eintraege():
    produkte = lade()
    assert len(produkte) >= 120
    assert len({p.id for p in produkte}) == len(produkte)


def test_vielfalt_der_kategorien():
    assert len({p.kategorie for p in lade()}) >= 25


def test_mindestens_10_absichtliche_ramsch_eintraege():
    assert sum(1 for p in lade() if pruefe_regeln(p) is not None) >= 10


def test_nicht_ramsch_hat_https_link():
    for p in lade():
        if pruefe_regeln(p) is None:
            assert p.link.startswith("https://"), p.id
