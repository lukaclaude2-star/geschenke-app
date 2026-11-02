"""Update per Fingertipp: SideStore liest hier die Quelle und lädt die neueste App.

Die .ipa liegt als GitHub-Release im privaten Repo. Der Server holt sie mit einem eigenen
Lese-Token und reicht sie durch (Render-Speicher ist flüchtig, deshalb wird nichts abgelegt).
Der Pfad enthält ein Geheimnis, weil SideStore keine Header schicken kann; falsches oder
fehlendes Geheimnis → 404, damit niemand erfährt, dass es den Pfad gibt.
"""

import hmac
import logging
import re
from pathlib import Path

import httpx
from fastapi import APIRouter, HTTPException, Response

from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

GITHUB_API = "https://api.github.com"
ASSET_NAME = "Geschenke.ipa"
TAG_MUSTER = re.compile(r"^app-(\d+)$")
ICON = Path(__file__).parent / "static" / "icon.png"


class GithubFehler(RuntimeError):
    pass


def _pruefe(geheimnis: str) -> None:
    erwartet = settings.download_geheimnis
    if not erwartet or not hmac.compare_digest(geheimnis.encode(), erwartet.encode()):
        raise HTTPException(status_code=404, detail="Not Found")


def _github_header(accept: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {settings.github_token}", "Accept": accept,
            "X-GitHub-Api-Version": "2022-11-28"}


async def _neuestes_release(client: httpx.AsyncClient) -> tuple[str, str, dict]:
    """→ (Build-Nummer, Datum, Asset) des neuesten Releases."""
    antwort = await client.get(f"{GITHUB_API}/repos/{settings.github_repo}/releases/latest",
                               headers=_github_header("application/vnd.github+json"))
    if antwort.status_code != 200:
        raise GithubFehler(f"Release-Abfrage: Status {antwort.status_code}")
    release = antwort.json()
    treffer = TAG_MUSTER.match(release.get("tag_name") or "")
    asset = next((a for a in release.get("assets") or [] if a.get("name") == ASSET_NAME), None)
    if not treffer or asset is None:
        raise GithubFehler("Release ohne passenden Tag oder ohne Geschenke.ipa")
    return treffer.group(1), release.get("published_at") or "", asset


async def _mit_github(arbeit):
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            return await arbeit(client)
    except (httpx.HTTPError, GithubFehler) as fehler:
        logger.warning("Download über GitHub fehlgeschlagen: %s", fehler)
        raise HTTPException(status_code=503, detail="Gerade nicht verfügbar") from None


@router.get("/dl/{geheimnis}/source.json")
async def quelle(geheimnis: str) -> dict:
    _pruefe(geheimnis)

    async def arbeit(client: httpx.AsyncClient) -> dict:
        nummer, datum, asset = await _neuestes_release(client)
        return {
            "name": "Geschenke (Luka)",
            "identifier": "de.luka.geschenke.quelle",
            "apps": [{
                "name": "Geschenke",
                "bundleIdentifier": "de.luka.geschenke",
                "developerName": "Luka",
                "localizedDescription": "Geschenke per Chat und Wischen finden.",
                "iconURL": f"{settings.oeffentliche_url}/dl/{geheimnis}/icon.png",
                "versions": [{
                    "version": f"1.0.{nummer}",
                    "buildVersion": nummer,
                    "date": datum,
                    "downloadURL": f"{settings.oeffentliche_url}/dl/{geheimnis}/{ASSET_NAME}",
                    "size": asset.get("size", 0),
                }],
            }],
            "news": [],
        }

    return await _mit_github(arbeit)


@router.get("/dl/{geheimnis}/Geschenke.ipa")
async def ipa(geheimnis: str) -> Response:
    _pruefe(geheimnis)

    async def arbeit(client: httpx.AsyncClient) -> Response:
        _, _, asset = await _neuestes_release(client)
        antwort = await client.get(f"{GITHUB_API}/repos/{settings.github_repo}/releases/assets/{asset['id']}",
                                   headers=_github_header("application/octet-stream"))
        if antwort.status_code in (301, 302, 303, 307, 308):
            # Das Weiterleitungsziel ist ein signierter Link – der GitHub-Token geht dort nicht mit.
            antwort = await client.get(antwort.headers["Location"])
        if antwort.status_code != 200:
            raise GithubFehler(f"Asset-Download: Status {antwort.status_code}")
        return Response(content=antwort.content, media_type="application/octet-stream",
                        headers={"Content-Disposition": f'attachment; filename="{ASSET_NAME}"'})

    return await _mit_github(arbeit)


@router.get("/dl/{geheimnis}/icon.png")
async def icon(geheimnis: str) -> Response:
    _pruefe(geheimnis)
    return Response(content=ICON.read_bytes(), media_type="image/png")
