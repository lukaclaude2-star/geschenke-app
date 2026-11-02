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


# --- Runde 3: Oberbereiche ---
import re

from app.vokabular import BEREICHE, THEMA_BEREICH, VOKABULAR_VERSION, vokabular_text


def test_270_stichwoerter_in_oberbereichen():
    assert len(THEMEN) == 252
    assert len(LEBENSLAGEN) == 18
    assert len(BEREICHE) == 21
    assert set(THEMA_BEREICH) == set(THEMEN)
    assert set(THEMA_BEREICH.values()) == set(BEREICHE)


def test_schluessel_sind_ascii_und_eindeutig():
    for tag in list(THEMEN) + list(LEBENSLAGEN) + list(BEREICHE):
        assert re.fullmatch(r"[a-z0-9_]+", tag), tag
    assert not set(THEMEN) & set(LEBENSLAGEN)


def test_neue_stichwoerter_da():
    for tag in ("grillen", "gaming", "heimwerken", "whisky", "lego", "anime", "kinder"):
        assert tag in THEMEN
    assert THEMEN["sport"] == "🏅 Sport"
    assert THEMA_BEREICH["grillen"] == THEMA_BEREICH["kochen"]
    assert "erste_wohnung" in LEBENSLAGEN


def test_vokabular_text_gruppiert():
    text = vokabular_text()
    assert "grillen" in text and "whisky" in text
    assert text.count("\n") >= len(BEREICHE) - 1
    assert VOKABULAR_VERSION >= 2
