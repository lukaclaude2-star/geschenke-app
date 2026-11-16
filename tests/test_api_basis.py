def test_health_ohne_token(client):
    assert client.get("/health").json() == {"ok": True}


def test_geschuetzte_route_ohne_token_401(client):
    assert client.post("/chat/naechste", json={}).status_code == 401


def test_falscher_token_401(client):
    r = client.post("/chat/naechste", json={}, headers={"Authorization": "Bearer falsch"})
    assert r.status_code == 401


def test_kaputter_body_mit_token_gibt_422(client, auth):
    assert client.post("/chat/naechste", json={"laenge": "ewig"}, headers=auth).status_code == 422


def test_mehrere_tokens_gelten_waehrend_des_wechsels(client, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "app_token", "neu, alt")
    for token in ("neu", "alt"):
        r = client.post("/chat/naechste", json={"laenge": "ewig"}, headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 422
    for falsch in ("", "neu, alt", "neu,alt", "ne"):
        r = client.post("/chat/naechste", json={}, headers={"Authorization": f"Bearer {falsch}"})
        assert r.status_code == 401


def test_umlaut_im_token_gibt_401(client):
    r = client.post("/chat/naechste", json={}, headers={"Authorization": "Bearer tést".encode("latin-1")})
    assert r.status_code == 401
