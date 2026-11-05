from scripts.bereiche_fuer_app import SWIFT_DATEI, swift_quelltext


def test_bereiche_swift_aktuell():
    """Die App ordnet die Merkliste nach Oberbereichen. Ändert sich das Vokabular, muss
    `python scripts/bereiche_fuer_app.py` die Swift-Tabelle neu schreiben."""
    assert SWIFT_DATEI.read_text(encoding="utf-8") == swift_quelltext()


def test_bereichsnamen_ohne_emoji():
    text = swift_quelltext()
    assert '"kueche": "Küche & Kochen"' in text
    assert '"grillen": "kueche"' in text
    assert "🍳" not in text
