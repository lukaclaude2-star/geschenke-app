import pytest

from app import ideen as ideen_modul
from app import main
from app.config import settings
from app.ideen import ideen_karten
from app.karten import karten_fuer, produkt_zu_karte
from app.ki import KiUeberlastet
from app.modelle import Ausschluss, KartenAnfrage, KatalogProdukt, Profil, Wunsch


def produkt(id: str, themen=("garten",), **abweichung) -> KatalogProdukt:
    werte = dict(
        id=id, titel=f"Produkt {id}", beschreibung="Beschreibung", preis=25.0,
        bild_url="https://x/b.jpg", link=f"https://x/{id}", shop="Shop",
        themen=list(themen), lebenslagen=["rente"], farben=[], eigenschaften=[],
        persoenlich=False, note=8, inhalts_hash="h",
    )
    werte.update(abweichung)
    return KatalogProdukt(**werte)


def profil(ausschluesse=(), budget_max=None) -> Profil:
    return Profil(zusammenfassung="Oma", wuensche=[Wunsch(tag="garten", label="g", gewicht=1.0)],
                  ausschluesse=[Ausschluss(schluessel=s, label=s) for s in ausschluesse],
                  budget_max=budget_max)


IDEE = {"titel": "Kniekissen für die Gartenarbeit", "emoji": "🧤", "preis_von": 15, "preis_bis": 25,
        "suchbegriff": "Kniekissen Garten", "themen": ["garten"]}


class FakeKi:
    def __init__(self, ideen=None):
        self.ideen = ideen if ideen is not None else [IDEE]
        self.aufrufe = 0

    async def __call__(self, *_, **__):
        self.aufrufe += 1
        return {"ideen": self.ideen}


@pytest.fixture
def ki(monkeypatch):
    fake = FakeKi()
    monkeypatch.setattr(ideen_modul, "frage_json", fake)
    return fake


def test_karte_hat_immer_link_und_tags():
    k = produkt_zu_karte(produkt("a"))
    assert k.link == "https://x/a" and k.art == "produkt" and k.tags == ["garten", "rente"]


async def test_genug_produkte_keine_ki(ki):
    katalog = [produkt(str(i)) for i in range(12)]
    antwort = await karten_fuer(katalog, KartenAnfrage(profil=profil(), anzahl=10))
    assert len(antwort.karten) == 10 and not antwort.wird_duenn and ki.aufrufe == 0


async def test_wird_duenn_fuellt_mit_ideen_auf(ki):
    antwort = await karten_fuer([produkt("a")], KartenAnfrage(profil=profil(), anzahl=10))
    assert [k.art for k in antwort.karten] == ["produkt", "idee"] and antwort.wird_duenn


async def test_idee_mit_ausgeschlossenem_wort_wird_verworfen(ki):
    assert await ideen_karten(profil(["wort:kissen"]), 5, set()) == []


async def test_idee_mit_ausgeschlossener_farbe_wird_verworfen(ki):
    ki.ideen = [{**IDEE, "titel": "Schwarzes Kniekissen"}]
    assert await ideen_karten(profil(["farbe:schwarz"]), 5, set()) == []


async def test_idee_mit_ausgeschlossenem_thema_wird_verworfen(ki):
    assert await ideen_karten(profil(["thema:garten"]), 5, set()) == []


async def test_idee_ueber_budget_wird_verworfen(ki):
    # Idee kostet 15–25 €: keine Überschneidung mit „bis 10 €“ → raus
    assert await ideen_karten(profil(budget_max=10), 5, set()) == []


async def test_idee_mit_ueberschneidung_bleibt(ki):
    # 15–25 € überschneidet sich mit „bis 20 €“ (Runde 2: Spanne muss sich überschneiden)
    assert len(await ideen_karten(profil(budget_max=20), 5, set())) == 1


async def test_idee_ohne_suchbegriff_wird_verworfen(ki):
    ki.ideen = [{**IDEE, "suchbegriff": ""}]
    assert await ideen_karten(profil(), 5, set()) == []


async def test_gesehene_idee_kommt_nicht_wieder(ki):
    assert await ideen_karten(profil(), 5, {"idee:kniekissen garten"}) == []


async def test_idee_link_mit_und_ohne_amazon_tag(ki, monkeypatch):
    [k] = await ideen_karten(profil(), 5, set())
    assert k.link == "https://www.amazon.de/s?k=Kniekissen+Garten"
    assert (k.preis, k.preis_von, k.preis_bis, k.emoji, k.bild_url) == (None, 15, 25, "🧤", None)
    monkeypatch.setattr(settings, "amazon_tag", "luka-21")
    [k] = await ideen_karten(profil(), 5, set())
    assert k.link == "https://www.amazon.de/s?k=Kniekissen+Garten&tag=luka-21"


async def test_ki_ueberlastet_liefert_nur_produkte_und_wird_duenn(monkeypatch):
    async def kaputt(*_, **__):
        raise KiUeberlastet()
    monkeypatch.setattr(ideen_modul, "frage_json", kaputt)
    antwort = await karten_fuer([produkt("a")], KartenAnfrage(profil=profil(), anzahl=10))
    assert [k.id for k in antwort.karten] == ["a"] and antwort.wird_duenn


async def test_tag_labels_decken_alle_kartentags_ab(ki):
    antwort = await karten_fuer([produkt("a")], KartenAnfrage(profil=profil(), anzahl=10))
    alle_tags = {t for k in antwort.karten for t in k.tags}
    assert alle_tags and alle_tags <= set(antwort.tag_labels)


def test_route_braucht_token(client):
    assert client.post("/karten", json={}).status_code == 401


def test_route_liefert_karten(client, auth, monkeypatch):
    monkeypatch.setattr(main, "KATALOG", [produkt(str(i)) for i in range(12)])
    body = {"profil": profil().model_dump(), "gesehen": [], "anzahl": 10}
    r = client.post("/karten", json=body, headers=auth)
    assert r.status_code == 200 and len(r.json()["karten"]) == 10
