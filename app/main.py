import hmac

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse

from app.config import settings
from app.gespraech import naechster_schritt
from app.ki import KiUeberlastet
from app.modelle import (ChatAnfrage, ChatAntwort, Profil, ProfilAendernAnfrage,
                         ProfilAusGespraechAnfrage)
from app.profil import profil_aendern, profil_aus_gespraech


def pruefe_token(authorization: str | None = Header(default=None)) -> None:
    """Die App schickt den Token im Header, nicht in der URL: URLs landen in Logs."""
    erwartet = f"Bearer {settings.app_token}"
    if not settings.app_token or not authorization or not hmac.compare_digest(authorization, erwartet):
        raise HTTPException(status_code=401, detail="Nicht berechtigt")


app = FastAPI(title="Geschenke")
geschuetzt = [Depends(pruefe_token)]


@app.exception_handler(KiUeberlastet)
async def ki_ueberlastet(_: Request, __: KiUeberlastet) -> JSONResponse:
    return JSONResponse(status_code=503, content={"fehler": "ki_ueberlastet"})


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


@app.post("/chat/naechste", dependencies=geschuetzt)
async def chat_naechste(anfrage: ChatAnfrage) -> ChatAntwort:
    return await naechster_schritt(anfrage)


@app.post("/profil/aus-gespraech", dependencies=geschuetzt)
async def route_profil_aus_gespraech(anfrage: ProfilAusGespraechAnfrage) -> Profil:
    return await profil_aus_gespraech(anfrage.nachrichten)


@app.post("/profil/aendern", dependencies=geschuetzt)
async def route_profil_aendern(anfrage: ProfilAendernAnfrage) -> Profil:
    return await profil_aendern(anfrage.profil, anfrage.anweisung)
