from app.vokabular import EIGENSCHAFTEN, FARBEN, LEBENSLAGEN, THEMEN, ist_gueltiger_ausschluss, label_fuer


def test_themen_ids_sind_klein_und_ohne_leerzeichen():
    for tag in list(THEMEN) + list(LEBENSLAGEN) + list(EIGENSCHAFTEN) + list(FARBEN):
        assert tag == tag.lower() and " " not in tag


def test_mindestens_40_themen():
    assert len(THEMEN) >= 40


def test_ausschluss_gueltig():
    for gut in ["thema:garten", "farbe:schwarz", "eigenschaft:alkohol", "wort:katzen"]:
        assert ist_gueltiger_ausschluss(gut), gut
    for schlecht in ["farbe:kariert", "thema:unbekannt", "wort:", "wort:   ", "xyz"]:
        assert not ist_gueltiger_ausschluss(schlecht), schlecht


def test_label_fuer_farbe():
    assert label_fuer("farbe:schwarz") == "Schwarz"


def test_label_fuer_thema_und_wort():
    assert label_fuer("thema:garten") == THEMEN["garten"]
    assert label_fuer("wort:katze") == "„katze“"


def test_wunsch_tag_teilt_keine_id_zwischen_themen_und_lebenslagen():
    assert not set(THEMEN) & set(LEBENSLAGEN)
