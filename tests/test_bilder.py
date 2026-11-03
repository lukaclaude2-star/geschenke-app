import pytest

from app import bilder
from app import ideen as ideen_modul
from app.bilder import beispielbild
from app.config import settings
from app.ideen import ideen_karten
from app.modelle import Profil, Wunsch
from app.vokabular import THEMEN


@pytest.fixture(autouse=True)
def nur_grillen_und_gaming(monkeypatch):
    monkeypatch.setattr(bilder, "VORHANDEN", {"grillen", "gaming"})


def test_foto_zum_ersten_stichwort_mit_foto():
    assert beispielbild(["grillen", "gaming"]) == f"{settings.oeffentliche_url}/beispielbilder/grillen.jpg"
    assert beispielbild(["whisky", "gaming"]) == f"{settings.oeffentliche_url}/beispielbilder/gaming.jpg"


def test_ohne_passendes_foto_kein_bild():
    assert beispielbild([]) is None
    assert beispielbild(["whisky"]) is None


async def test_ideenkarte_bekommt_beispielbild(monkeypatch):
    async def ki(*_, **__):
        return {"ideen": [
            {"titel": "Gaming-Headset", "emoji": "🎧", "preis_von": 30, "preis_bis": 60,
             "suchbegriff": "Gaming Headset", "themen": ["gaming"]},
            {"titel": "Whisky-Steine", "emoji": "🥃", "preis_von": 15, "preis_bis": 25,
             "suchbegriff": "Whisky Steine", "themen": ["whisky"]}]}
    monkeypatch.setattr(ideen_modul, "frage_json", ki)
    profil = Profil(zusammenfassung="Papa", ausschluesse=[], wuensche=[Wunsch(tag="gaming", label="g", gewicht=1)])
    mit, ohne = await ideen_karten(profil, 3, set())
    assert mit.bild_url == f"{settings.oeffentliche_url}/beispielbilder/gaming.jpg"
    assert mit.beispielbild is True
    assert ohne.bild_url is None
    assert ohne.beispielbild is False


def test_jedes_stichwort_hat_ein_foto(monkeypatch):
    """Neue Stichwörter brauchen ein Foto: scripts/hole_beispielbilder.py."""
    monkeypatch.undo()
    fehlend = sorted(set(THEMEN) - bilder.VORHANDEN)
    assert fehlend == []


def test_server_liefert_foto(client):
    datei = next(bilder.ORDNER.glob("*.jpg"))
    antwort = client.get(f"/beispielbilder/{datei.name}")
    assert antwort.status_code == 200
    assert antwort.headers["content-type"] == "image/jpeg"
