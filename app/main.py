import hmac

from fastapi import Depends, FastAPI, Header, HTTPException

from app.config import settings
from app.gespraech import naechster_schritt
from app.modelle import ChatAnfrage, ChatAntwort


def pruefe_token(authorization: str | None = Header(default=None)) -> None:
    """Die App schickt den Token im Header, nicht in der URL: URLs landen in Logs."""
    erwartet = f"Bearer {settings.app_token}"
    if not settings.app_token or not authorization or not hmac.compare_digest(authorization, erwartet):
        raise HTTPException(status_code=401, detail="Nicht berechtigt")


app = FastAPI(title="Geschenke")
geschuetzt = [Depends(pruefe_token)]


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


@app.post("/chat/naechste", dependencies=geschuetzt)
async def chat_naechste(anfrage: ChatAnfrage) -> ChatAntwort:
    return await naechster_schritt(anfrage)
