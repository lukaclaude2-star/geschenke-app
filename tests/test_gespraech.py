import pytest

from app import gespraech
from app.gespraech import ERSTE_FRAGE, SCHLUSSFRAGE, naechster_schritt
from app.ki import KiUeberlastet
from app.modelle import ChatAnfrage, ChatNachricht


class FakeKi:
    def __init__(self, genug=False):
        self.genug = genug
        self.aufrufe = 0

    async def __call__(self, system, nutzer, **_):
        self.aufrufe += 1
        return {"genug": self.genug, "frage": f"KI-Frage {self.aufrufe}?", "platzhalter": "z. B. etwas"}


@pytest.fixture
def ki(monkeypatch):
    fake = FakeKi()
    monkeypatch.setattr(gespraech, "frage_json", fake)
    return fake


def verlauf(*paare) -> list[ChatNachricht]:
    """paare: (app_text, nutzer_text) – nutzer_text None = noch keine Antwort."""
    nachrichten = []
    for app_text, nutzer_text in paare:
        nachrichten.append(ChatNachricht(rolle="app", text=app_text))
        if nutzer_text is not None:
            nachrichten.append(ChatNachricht(rolle="nutzer", text=nutzer_text))
    return nachrichten


def anfrage(laenge, *paare):
    return ChatAnfrage(laenge=laenge, nachrichten=verlauf(*paare))


async def test_start_liefert_erste_frage_ohne_ki(ki):
    a = await naechster_schritt(ChatAnfrage(laenge="normal", nachrichten=[]))
    assert (a.fertig, a.frage) == (False, ERSTE_FRAGE) and a.platzhalter and ki.aufrufe == 0


async def test_schnell_nach_max_eine_ki_frage_kommt_schlussfrage(ki):
    a = await naechster_schritt(anfrage("schnell", (ERSTE_FRAGE, "Oma"), ("KI-Frage 1?", "Garten")))
    assert a.frage == SCHLUSSFRAGE and ki.aufrufe == 0


async def test_schnell_erste_ki_frage_wird_gestellt(ki):
    a = await naechster_schritt(anfrage("schnell", (ERSTE_FRAGE, "Oma")))
    assert a.frage == "KI-Frage 1?" and a.platzhalter == "z. B. etwas"


async def test_gruendlich_ignoriert_genug_vor_minimum(ki):
    ki.genug = True
    a = await naechster_schritt(anfrage("gruendlich", (ERSTE_FRAGE, "Oma"), ("F1?", "Garten")))
    assert a.frage not in (SCHLUSSFRAGE, None)


async def test_normal_genug_nach_minimum_fuehrt_zur_schlussfrage(ki):
    ki.genug = True
    a = await naechster_schritt(anfrage("normal", (ERSTE_FRAGE, "Oma"), ("F1?", "Garten")))
    assert a.frage == SCHLUSSFRAGE


async def test_antwort_auf_schlussfrage_ist_fertig(ki):
    a = await naechster_schritt(anfrage("normal", (ERSTE_FRAGE, "Oma"), (SCHLUSSFRAGE, "nein")))
    assert a.fertig is True and a.frage is None


async def test_kurze_und_leere_antworten_brechen_nichts(ki):
    paare = [(ERSTE_FRAGE, "")]
    for _ in range(20):
        a = await naechster_schritt(anfrage("gruendlich", *paare))
        if a.fertig:
            break
        paare.append((a.frage, "weiß nicht"))
    assert a.fertig
    app_fragen = [p[0] for p in paare]
    assert app_fragen[-1] == SCHLUSSFRAGE
    assert len(app_fragen) == 1 + 6 + 1  # erste + max KI-Fragen (gründlich) + Schluss


async def test_ki_ueberlastet_fuehrt_zur_schlussfrage(monkeypatch):
    async def kaputt(*_, **__):
        raise KiUeberlastet()
    monkeypatch.setattr(gespraech, "frage_json", kaputt)
    a = await naechster_schritt(anfrage("gruendlich", (ERSTE_FRAGE, "Oma")))
    assert a.frage == SCHLUSSFRAGE


async def test_noch_unbeantwortete_frage_wird_wiederholt(ki):
    a = await naechster_schritt(anfrage("normal", (ERSTE_FRAGE, None)))
    assert a.frage == ERSTE_FRAGE and ki.aufrufe == 0


def test_route_braucht_token(client):
    assert client.post("/chat/naechste", json={"laenge": "normal", "nachrichten": []}).status_code == 401


def test_route_liefert_erste_frage(client, auth):
    r = client.post("/chat/naechste", json={"laenge": "normal", "nachrichten": []}, headers=auth)
    assert r.status_code == 200 and r.json()["frage"] == ERSTE_FRAGE
