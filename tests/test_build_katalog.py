import json

from app.katalog.laden import lade_alle
from scripts.build_katalog import katalog_text
from tests.test_ranking import produkt


def test_katalog_text_ein_produkt_pro_zeile_und_ladbar(tmp_path):
    """Mit ~50.000 Produkten muss katalog.json klein bleiben (GitHub warnt ab 50 MB) und
    trotzdem zeilenweise Diffs haben, sonst wächst das Repo mit jedem Nachtlauf stark."""
    ps = [produkt("a", titel="Stiefel „Berta“"), produkt("b")]
    text = katalog_text(ps)
    zeilen = text.splitlines()
    assert zeilen[0] == "[" and zeilen[-1] == "]" and len(zeilen) == 4
    assert ": " not in zeilen[1] and "„Berta“" in zeilen[1]
    datei = tmp_path / "k.json"
    datei.write_text(text, encoding="utf-8")
    assert [p.model_dump() for p in lade_alle(str(datei))] == [p.model_dump() for p in ps]


def test_katalog_text_leer():
    assert json.loads(katalog_text([])) == []
