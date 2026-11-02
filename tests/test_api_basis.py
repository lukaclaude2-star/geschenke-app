def test_health_ohne_token(client):
    assert client.get("/health").json() == {"ok": True}


def test_geschuetzte_route_ohne_token_401(client):
    assert client.post("/chat/naechste", json={}).status_code == 401


def test_falscher_token_401(client):
    r = client.post("/chat/naechste", json={}, headers={"Authorization": "Bearer falsch"})
    assert r.status_code == 401
