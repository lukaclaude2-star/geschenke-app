from app.gespraech import SYSTEM
from app.ideen import spanne_im_budget
from app.modelle import Profil, Wunsch
from app.profil import wende_aenderung_an
from app.ranking import im_budget, waehle_karten
from tests.test_ranking import produkt


def test_budget_min_ist_hart():
    katalog = [produkt("a", preis=10), produkt("b", preis=30), produkt("c", preis=60)]
    profil = Profil(zusammenfassung="x", wuensche=[Wunsch(tag="garten", label="Garten", gewicht=1.5)],
                    ausschluesse=[], budget_min=20, budget_max=50)
    produkte, _ = waehle_karten(katalog, profil, set(), 10)
    assert [p.preis for p in produkte] == [30]


def test_im_budget():
    p = Profil(zusammenfassung="x", wuensche=[], ausschluesse=[], budget_min=20, budget_max=50)
    assert im_budget(20, p) and im_budget(50, p)
    assert not im_budget(19.99, p) and not im_budget(50.01, p)
    assert im_budget(999, Profil(zusammenfassung="x", wuensche=[], ausschluesse=[]))


def test_altes_profil_ohne_budget_min():
    assert Profil.model_validate({"zusammenfassung": "x", "wuensche": [], "ausschluesse": [],
                                  "budget_max": 50}).budget_min is None


def test_spanne_im_budget():
    p = Profil(zusammenfassung="x", wuensche=[], ausschluesse=[], budget_min=40, budget_max=50)
    assert spanne_im_budget(10, 30, p) is False
    assert spanne_im_budget(30, 60, p) is True
    assert spanne_im_budget(None, None, p) is False
    assert spanne_im_budget(None, None, Profil(zusammenfassung="x", wuensche=[], ausschluesse=[])) is True
    nur_max = Profil(zusammenfassung="x", wuensche=[], ausschluesse=[], budget_max=50)
    assert spanne_im_budget(None, 40, nur_max) is True
    assert spanne_im_budget(60, None, nur_max) is False


def test_aenderung_setzt_budget_min():
    p = Profil(zusammenfassung="x", wuensche=[], ausschluesse=[], budget_min=None, budget_max=50)
    neu = wende_aenderung_an(p, {"budget_min": 20})
    assert (neu.budget_min, neu.budget_max) == (20, 50)
    assert wende_aenderung_an(neu, {}).budget_min == 20
    assert wende_aenderung_an(neu, {"budget_min": None}).budget_min is None


def test_gespraech_fragt_nicht_nach_budget():
    assert "Wenn das Budget noch fehlt" not in SYSTEM
    assert "Nach dem Budget fragst du nie" in SYSTEM
