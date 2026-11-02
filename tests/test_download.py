import httpx
import pytest
import respx

from app.config import settings

REPO = "lukaclaude2-star/geschenke-app"
LATEST = f"https://api.github.com/repos/{REPO}/releases/latest"
ASSET = f"https://api.github.com/repos/{REPO}/releases/assets/7"
S3 = "https://objects.githubusercontent.com/datei?sig=abc"

RELEASE = {
    "tag_name": "app-42",
    "published_at": "2026-11-03T10:00:00Z",
    "assets": [{"id": 7, "name": "Geschenke.ipa", "size": 1234}],
}


@pytest.fixture
def konfiguriert(monkeypatch):
    monkeypatch.setattr(settings, "download_geheimnis", "geheim")
    monkeypatch.setattr(settings, "github_token", "tok")
    monkeypatch.setattr(settings, "github_repo", REPO)
    monkeypatch.setattr(settings, "oeffentliche_url", "https://geschenke.onrender.com")


def test_falsches_geheimnis_404(client, konfiguriert):
    assert client.get("/dl/falsch/source.json").status_code == 404
    assert client.get("/dl/falsch/Geschenke.ipa").status_code == 404


def test_ohne_konfiguration_404(client, monkeypatch):
    monkeypatch.setattr(settings, "download_geheimnis", "")
    assert client.get("/dl/x/source.json").status_code == 404
    assert client.get("/dl//source.json").status_code == 404


@respx.mock
def test_source_json_aus_release(client, konfiguriert):
    respx.get(LATEST).mock(return_value=httpx.Response(200, json=RELEASE))
    r = client.get("/dl/geheim/source.json")
    assert r.status_code == 200
    app = r.json()["apps"][0]
    assert app["bundleIdentifier"] == "de.luka.geschenke"
    v = app["versions"][0]
    assert (v["version"], v["buildVersion"], v["size"]) == ("1.0.42", "42", 1234)
    assert v["date"] == "2026-11-03T10:00:00Z"
    assert v["downloadURL"] == "https://geschenke.onrender.com/dl/geheim/Geschenke.ipa"


@respx.mock
def test_ipa_wird_durchgereicht(client, konfiguriert):
    respx.get(LATEST).mock(return_value=httpx.Response(200, json=RELEASE))
    respx.get(ASSET).mock(return_value=httpx.Response(302, headers={"Location": S3}))
    respx.get(S3).mock(return_value=httpx.Response(200, content=b"IPA"))
    r = client.get("/dl/geheim/Geschenke.ipa")
    assert r.status_code == 200 and r.content == b"IPA"
    assert r.headers["content-type"] == "application/octet-stream"


@respx.mock
def test_token_geht_nur_an_github(client, konfiguriert):
    respx.get(LATEST).mock(return_value=httpx.Response(200, json=RELEASE))
    asset = respx.get(ASSET).mock(return_value=httpx.Response(302, headers={"Location": S3}))
    s3 = respx.get(S3).mock(return_value=httpx.Response(200, content=b"IPA"))
    client.get("/dl/geheim/Geschenke.ipa")
    assert asset.calls.last.request.headers["Authorization"] == "Bearer tok"
    assert "Authorization" not in s3.calls.last.request.headers


@respx.mock
def test_github_nicht_erreichbar_503(client, konfiguriert):
    respx.get(LATEST).mock(side_effect=httpx.ConnectError("weg"))
    assert client.get("/dl/geheim/source.json").status_code == 503


@respx.mock
def test_kein_release_503(client, konfiguriert):
    respx.get(LATEST).mock(return_value=httpx.Response(404))
    assert client.get("/dl/geheim/source.json").status_code == 503


@respx.mock
def test_release_ohne_ipa_503(client, konfiguriert):
    respx.get(LATEST).mock(return_value=httpx.Response(200, json={**RELEASE, "assets": []}))
    assert client.get("/dl/geheim/source.json").status_code == 503
