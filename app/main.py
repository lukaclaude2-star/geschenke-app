import hmac

from fastapi import FastAPI, Header, HTTPException

from app.config import settings

app = FastAPI(title="Geschenke")


def pruefe_token(authorization: str | None) -> None:
    erwartet = f"Bearer {settings.app_token}"
    if not settings.app_token or not authorization or not hmac.compare_digest(authorization, erwartet):
        raise HTTPException(status_code=401, detail="Nicht berechtigt")


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


@app.post("/chat/naechste")
def chat_naechste(authorization: str | None = Header(default=None)) -> None:
    pruefe_token(authorization)
    raise HTTPException(status_code=501, detail="Noch nicht gebaut")
