import hmac

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.bilder import ORDNER as BILDER_ORDNER
from app.config import settings
from app.download import router as download_router
from app.rechtliches import router as rechtliches_router
from app.drossel import Drossel, schluessel_fuer
from app.gespraech import naechster_schritt
from app.karten import karten_fuer, sammel_karten_fuer
from app.katalog.laden import lade_katalog
from app.ki import KiUeberlastet
from app.modelle import (ChatAnfrage, ChatAntwort, KartenAnfrage, KartenAntwort, KartenSammelAnfrage,
                         KartenSammelAntwort, Profil,
                         ProfilAendernAnfrage, ProfilAusGespraechAnfrage)
from app.profil import profil_aendern, profil_aus_gespraech


def pruefe_token(authorization: str | None = Header(default=None)) -> None:
    """Die App schickt den Token im Header, nicht in der URL: URLs landen in Logs."""
    erwartet = f"Bearer {settings.app_token}"
    if not settings.app_token or not authorization or not hmac.compare_digest(authorization, erwartet):
        raise HTTPException(status_code=401, detail="Nicht berechtigt")


# Die Schnittstellen-Doku (/docs, /redoc, /openapi.json) bleibt aus: Sie würde jedem zeigen,
# welche Routen es gibt und was sie annehmen.
DROSSEL = Drossel(pro_minute=settings.drossel_pro_minute, pro_tag=settings.drossel_pro_tag)


def _gedrosselt(request: Request, kosten: int) -> None:
    if not DROSSEL.erlaubt(schluessel_fuer(request), kosten):
        raise HTTPException(status_code=429, detail="zu_viele_anfragen")


async def drosseln(request: Request) -> None:
    # async: läuft auf der Ereignisschleife statt im Thread-Pool, also nie zwei gleichzeitig am Dict.
    # Keine weiteren Parameter: FastAPI machte sie zu Query-Parametern, die der Client setzen kann.
    _gedrosselt(request, 1)


app = FastAPI(title="Geschenke", docs_url=None, redoc_url=None, openapi_url=None)
# Erst der Token, dann die Drossel: Fremde ohne Token verbrauchen keine Zähler.
geschuetzt = [Depends(pruefe_token), Depends(drosseln)]

# Größte erlaubte Anfrage. Die längste echte ist die Sammelsuche mit 12 Profilen und deren
# Gesehen-Listen, sie bleibt weit darunter.
MAX_ANFRAGE_BYTES = 4_000_000
SICHERHEITS_HEADER = {
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "X-Frame-Options": "DENY",
    "Strict-Transport-Security": "max-age=31536000",
}
HTML_CSP = ("default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; base-uri 'none'; "
            "form-action 'none'; frame-ancestors 'none'")


@app.middleware("http")
async def schutz(request: Request, call_next):
    if request.method == "POST":
        laenge = request.headers.get("content-length")
        if laenge is None:
            # Ohne Länge ließe sich ein beliebig großer Rumpf stückweise schicken.
            return JSONResponse(status_code=411, content={"fehler": "laenge_fehlt"})
        if not laenge.isdigit() or int(laenge) > MAX_ANFRAGE_BYTES:
            return JSONResponse(status_code=413, content={"fehler": "zu_gross"})
    antwort = await call_next(request)
    for name, wert in SICHERHEITS_HEADER.items():
        antwort.headers.setdefault(name, wert)
    if antwort.headers.get("content-type", "").startswith("text/html"):
        antwort.headers.setdefault("Content-Security-Policy", HTML_CSP)
    return antwort

app.include_router(download_router)
app.include_router(rechtliches_router)
# Fotos sind nicht geheim; die App lädt sie wie fremde Produktbilder ohne Token.
app.mount("/beispielbilder", StaticFiles(directory=BILDER_ORDNER, check_dir=False), name="beispielbilder")

# Der Katalog wird einmal beim Start geladen; der tägliche Lauf committet eine neue
# Datei, Render baut daraufhin neu und lädt sie.
KATALOG = lade_katalog(settings.katalog_pfad)


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


@app.post("/karten", dependencies=geschuetzt)
async def route_karten(anfrage: KartenAnfrage) -> KartenAntwort:
    return await karten_fuer(KATALOG, anfrage)


@app.post("/karten/sammel", dependencies=geschuetzt)
async def route_karten_sammel(anfrage: KartenSammelAnfrage, request: Request) -> KartenSammelAntwort:
    # Jede Person kann eine eigene KI-Anfrage auslösen; eine zählt schon die Abhängigkeit.
    _gedrosselt(request, kosten=len(anfrage.personen) - 1)
    return await sammel_karten_fuer(KATALOG, anfrage)
