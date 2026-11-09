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


def test_470_stichwoerter_in_oberbereichen():
    assert len(THEMEN) == 525
    assert len(LEBENSLAGEN) == 18
    assert len(BEREICHE) == 24
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


def test_bandbreite_runde_5():
    for tag in ("padel", "harry_potter", "muenzen", "kuscheltiere", "espresso", "tracht"):
        assert tag in THEMEN
    assert THEMA_BEREICH["muenzen"] == "sammeln"
    assert THEMA_BEREICH["kuscheltiere"] == "baby_kind"


def test_labels_beginnen_mit_emoji_und_sind_eindeutig():
    texte = [label.split(" ", 1) for label in THEMEN.values()]
    assert all(len(t) == 2 and not t[0].isalnum() for t in texte)
    namen = [t[1].lower() for t in texte]
    assert len(namen) == len(set(namen))


def test_vokabular_text_gruppiert():
    text = vokabular_text()
    assert "grillen" in text and "whisky" in text
    assert text.count("\n") >= len(BEREICHE) - 1
    assert VOKABULAR_VERSION >= 3


def test_vokabular_text_ohne_bereichsueberschriften():
    """Die KI soll Stichwörter vergeben, nicht Bereiche wie „baby_kind“ oder „Handwerk & DIY“."""
    text = vokabular_text()
    for name in BEREICHE.values():
        assert name.split(" ", 1)[1] not in text
    assert "baby_kind" not in text and "[" not in text
    assert len(text.splitlines()) == len(BEREICHE)
    assert text.splitlines()[0].strip().startswith("kochen, backen")


# --- Runde „Katalog groß“: Kleidung in drei Stufen, Franchises ---
from app.vokabular import GRUPPEN, THEMA_GRUPPE, mit_gruppen


def test_kleidung_drei_stufen():
    assert THEMA_GRUPPE["stiefel"] == "schuhe"
    assert THEMA_GRUPPE["sneaker"] == "schuhe"
    assert THEMA_GRUPPE["t_shirts"] == "oberteile"
    assert "schuhe" in THEMEN and THEMA_BEREICH["schuhe"] == "mode"
    assert all(THEMA_BEREICH[g] == "mode" for g in GRUPPEN)
    assert all(THEMA_BEREICH[t] == THEMA_BEREICH[g] for g, ts in GRUPPEN.items() for t in ts)
    assert not set(GRUPPEN) & set(THEMA_GRUPPE)  # Gruppe ist nie selbst Kind


def test_mit_gruppen():
    assert mit_gruppen(["stiefel", "grillen"]) == {"stiefel", "schuhe", "grillen"}
    assert mit_gruppen([]) == set()


def test_franchises_und_umzug_alter_schluessel():
    assert BEREICHE["franchises"]
    for tag in ("hello_kitty", "marvel", "harry_potter", "pokemon", "star_wars"):
        assert THEMA_BEREICH[tag] == "franchises"
    assert THEMA_BEREICH["lego"] == "spiele"
    assert THEMA_BEREICH["schmuck"] == "mode"  # alter Schlüssel, jetzt Gruppe
    assert VOKABULAR_VERSION == 4
