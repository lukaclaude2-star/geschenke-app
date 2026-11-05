import pytest

import app.karten as karten_modul
from app.modelle import (Ausschluss, KartenSammelAnfrage, Profil, SammelPerson, Wunsch)
from app.karten import sammel_karten_fuer
from tests.test_ranking import produkt


def profil(wuensche: dict[str, float], ausschluesse=(), budget_max=None) -> Profil:
    return Profil(
        zusammenfassung="x",
        wuensche=[Wunsch(tag=t, label=t, gewicht=g) for t, g in wuensche.items()],
        ausschluesse=[Ausschluss(schluessel=s, label=s) for s in ausschluesse],
        budget_max=budget_max,
    )


@pytest.fixture(autouse=True)
def keine_ideen(monkeypatch):
    async def leer(*_, **__):
        return []
    monkeypatch.setattr(karten_modul, "ideen_karten", leer)


@pytest.fixture
def katalog():
    return [
        produkt("wein1", themen=("wein",), titel="Rotwein-Tasting", eigenschaften=["alkohol"]),
        produkt("garten1", themen=("garten",)),
        produkt("garten2", themen=("garten",)),
        produkt("garten3", themen=("garten",)),
        produkt("buch1", themen=("buecher",)),
        produkt("buch2", themen=("buecher",)),
        produkt("buch3", themen=("buecher",)),
    ]


async def test_ausschluss_gilt_nur_fuer_die_person(katalog):
    mama = SammelPerson(id="mama", profil=profil({"wein": 1.5}, ausschluesse=["eigenschaft:alkohol"]))
    papa = SammelPerson(id="papa", profil=profil({"wein": 1.0}))
    antwort = await sammel_karten_fuer(katalog, KartenSammelAnfrage(personen=[mama, papa], anzahl=10))
    wein = [k for k in antwort.karten if "wein" in k.karte.tags]
    assert wein and all(k.fuer == "papa" for k in wein)


async def test_karte_erscheint_nur_einmal_bei_bester_person(katalog):
    mama = SammelPerson(id="mama", profil=profil({"garten": 1.5}))
    papa = SammelPerson(id="papa", profil=profil({"garten": 0.5, "buecher": 1.5}))
    antwort = await sammel_karten_fuer(katalog, KartenSammelAnfrage(personen=[mama, papa], anzahl=10))
    ids = [k.karte.id for k in antwort.karten]
    assert len(ids) == len(set(ids))
    garten = [k for k in antwort.karten if k.karte.id.startswith("garten")]
    assert len(garten) == 3 and all(k.fuer == "mama" for k in garten)


async def test_reissverschluss(katalog):
    mama = SammelPerson(id="mama", profil=profil({"garten": 1.5}))
    papa = SammelPerson(id="papa", profil=profil({"buecher": 1.5}))
    antwort = await sammel_karten_fuer(katalog, KartenSammelAnfrage(personen=[mama, papa], anzahl=4))
    assert [k.fuer for k in antwort.karten] == ["mama", "papa", "mama", "papa"]


async def test_gesehen_pro_person(katalog):
    mama = SammelPerson(id="mama", profil=profil({"garten": 1.5}), gesehen=["garten1"])
    papa = SammelPerson(id="papa", profil=profil({"garten": 1.0}))
    antwort = await sammel_karten_fuer(katalog, KartenSammelAnfrage(personen=[mama, papa], anzahl=10))
    zuordnung = {k.karte.id: k.fuer for k in antwort.karten}
    assert zuordnung["garten1"] == "papa"
    assert zuordnung["garten2"] == "mama"


async def test_budget_pro_person(katalog):
    katalog.append(produkt("garten_teuer", themen=("garten",), preis=200))
    mama = SammelPerson(id="mama", profil=profil({"garten": 1.5}, budget_max=50))
    papa = SammelPerson(id="papa", profil=profil({"garten": 0.5}))
    antwort = await sammel_karten_fuer(katalog, KartenSammelAnfrage(personen=[mama, papa], anzahl=10))
    zuordnung = {k.karte.id: k.fuer for k in antwort.karten}
    assert zuordnung["garten_teuer"] == "papa"


async def test_duenn_fuer_meldet_personen_mit_zu_wenig(katalog):
    mama = SammelPerson(id="mama", profil=profil({"garten": 1.5}))
    papa = SammelPerson(id="papa", profil=profil({"angeln": 1.5}))
    antwort = await sammel_karten_fuer(katalog, KartenSammelAnfrage(personen=[mama, papa], anzahl=4))
    assert antwort.duenn_fuer == ["papa"]


def test_route_braucht_token_und_zwei_personen(client, auth):
    eine = {"personen": [{"id": "a", "profil": {"zusammenfassung": "x", "wuensche": [], "ausschluesse": []}}]}
    assert client.post("/karten/sammel", json=eine).status_code == 401
    assert client.post("/karten/sammel", json=eine, headers=auth).status_code == 422


def test_sammelsuche_zaehlt_je_person(client, auth, monkeypatch):
    # Jede Person kann eine eigene KI-Anfrage auslösen, also zählt jede für die Drossel.
    from app import main
    from app.drossel import Drossel
    monkeypatch.setattr(main, "DROSSEL", Drossel(pro_minute=5, pro_tag=100))
    person = {"profil": {"zusammenfassung": "x", "wuensche": [], "ausschluesse": []}}
    vier = {"personen": [{"id": str(i), **person} for i in range(4)]}
    status = [client.post("/karten/sammel", json=vier, headers=auth).status_code for _ in range(2)]
    assert status == [200, 429]


async def test_ideen_fuer_mehrere_personen_laufen_gleichzeitig(katalog, monkeypatch):
    import asyncio
    import time

    async def langsam(*_, **__):
        await asyncio.sleep(0.2)
        return []
    monkeypatch.setattr(karten_modul, "ideen_karten", langsam)
    personen = [SammelPerson(id=str(i), profil=profil({"angeln": 1.5})) for i in range(3)]
    start = time.perf_counter()
    await sammel_karten_fuer(katalog, KartenSammelAnfrage(personen=personen, anzahl=6))
    assert time.perf_counter() - start < 0.4
