import json

from app import ideen as ideen_modul
from app.karten import karten_fuer, sammel_karten_fuer, unterversorgt
from app.modelle import KartenAnfrage, KartenSammelAnfrage, Profil, SammelPerson, Wunsch
from app.ranking import kandidaten
from tests.test_karten import produkt


def profil(*wuensche) -> Profil:
    return Profil(zusammenfassung="Papa", ausschluesse=[],
                  wuensche=[Wunsch(tag=t, label=t, gewicht=g) for t, g in wuensche])


GAMING_IDEE = {"titel": "Gaming-Headset", "emoji": "🎧", "preis_von": 30, "preis_bis": 60,
               "suchbegriff": "Gaming Headset", "themen": ["gaming"]}


class MerkKi:
    def __init__(self, ideen):
        self.ideen = ideen
        self.anfragen = []

    async def __call__(self, system, nutzer, **_):
        self.anfragen.append(json.loads(nutzer))
        return {"ideen": self.ideen}


KOCHEN = [produkt(f"k{i}", themen=("kochen",)) for i in range(12)]


def test_unterversorgt_findet_wunsch_ohne_produkte():
    p = profil(("kochen", 1.0), ("gaming", 1.0))
    assert unterversorgt(kandidaten(KOCHEN, p, set()), p) == ["gaming"]


def test_nebensaechlicher_wunsch_zaehlt_nicht():
    p = profil(("kochen", 1.0), ("gaming", 0.3))
    assert unterversorgt(kandidaten(KOCHEN, p, set()), p) == []


def test_oberbereich_treffer_versorgen_nicht():
    p = profil(("whisky", 1.0))
    wein = [produkt(f"w{i}", themen=("wein",)) for i in range(5)]
    assert unterversorgt(kandidaten(wein, p, set()), p) == ["whisky"]


async def test_reserve_fuer_ideen_und_schwerpunkt(monkeypatch):
    ki = MerkKi([GAMING_IDEE, dict(GAMING_IDEE, suchbegriff="Gaming Maus", titel="Gaming-Maus")])
    monkeypatch.setattr(ideen_modul, "frage_json", ki)
    antwort = await karten_fuer(KOCHEN, KartenAnfrage(profil=profil(("kochen", 1.0), ("gaming", 1.0)), anzahl=12))
    assert ki.anfragen and ki.anfragen[0]["schwerpunkt"] == ["gaming"]
    arten = [k.art for k in antwort.karten]
    assert arten.count("idee") == 2
    assert "idee" in arten[:3]  # Ideen kommen früh, nicht erst am Ende
    assert len(antwort.karten) == 12


async def test_ki_faellt_aus_dann_mehr_produkte(monkeypatch):
    monkeypatch.setattr(ideen_modul, "frage_json", MerkKi([]))
    antwort = await karten_fuer(KOCHEN, KartenAnfrage(profil=profil(("kochen", 1.0), ("gaming", 1.0)), anzahl=12))
    assert len(antwort.karten) == 12 and all(k.art == "produkt" for k in antwort.karten)


async def test_sammelsuche_nutzt_reserve(monkeypatch):
    ki = MerkKi([GAMING_IDEE])
    monkeypatch.setattr(ideen_modul, "frage_json", ki)
    garten = [produkt(f"g{i}", themen=("garten",)) for i in range(12)]
    anfrage = KartenSammelAnfrage(anzahl=12, personen=[
        SammelPerson(id="papa", profil=profil(("kochen", 1.0), ("gaming", 1.0)), gesehen=[]),
        SammelPerson(id="oma", profil=profil(("garten", 1.0)), gesehen=[]),
    ])
    antwort = await sammel_karten_fuer(KOCHEN + garten, anfrage)
    assert [a["schwerpunkt"] for a in ki.anfragen] == [["gaming"]]
    assert any(k.karte.art == "idee" and k.fuer == "papa" for k in antwort.karten)
