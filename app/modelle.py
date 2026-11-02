import html
import re
from typing import Literal

from pydantic import BaseModel, Field, field_validator


def ohne_html(text: str) -> str:
    """Feeds liefern Beschreibungen oft mit HTML-Resten (<p>, &nbsp;)."""
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)  # &nbsp; wird ein geschütztes Leerzeichen, das \s unten mitnimmt
    return re.sub(r"\s+", " ", text).strip()


class QuellProdukt(BaseModel):
    """Ein Produkt, wie es aus einem Partner-Feed (oder der Testliste) kommt."""

    id: str
    titel: str
    beschreibung: str
    preis: float
    bild_url: str | None
    bild_breite: int | None = None
    link: str
    shop: str
    kategorie: str = ""
    lieferbar: bool = True
    farbe: str | None = None
    varianten_gruppe: str | None = None

    @field_validator("beschreibung", mode="before")
    @classmethod
    def _beschreibung_ohne_html(cls, wert):
        return ohne_html(wert) if isinstance(wert, str) else wert


class KatalogProdukt(QuellProdukt):
    """Ein Produkt, das den Ramsch-Filter bestanden hat und verschlagwortet ist."""

    themen: list[str]
    lebenslagen: list[str]
    farben: list[str]
    eigenschaften: list[str]
    persoenlich: bool
    note: int
    inhalts_hash: str


class Wunsch(BaseModel):
    tag: str
    label: str
    gewicht: float


class Ausschluss(BaseModel):
    schluessel: str
    label: str


class Profil(BaseModel):
    zusammenfassung: str
    wuensche: list[Wunsch]
    ausschluesse: list[Ausschluss]
    budget_min: float | None = None
    budget_max: float | None = None


class Karte(BaseModel):
    id: str
    art: Literal["produkt", "idee"]
    titel: str
    preis: float | None
    preis_von: float | None = None
    preis_bis: float | None = None
    bild_url: str | None
    emoji: str | None = None
    shop: str
    link: str
    tags: list[str]
    # Ideenkarte mit Foto, das nur ein Beispiel zeigt (nicht das exakte Produkt).
    beispielbild: bool = False


class ChatNachricht(BaseModel):
    rolle: Literal["app", "nutzer"]
    text: str


class ChatAnfrage(BaseModel):
    laenge: Literal["schnell", "normal", "gruendlich"]
    nachrichten: list[ChatNachricht]


class ChatAntwort(BaseModel):
    fertig: bool
    frage: str | None = None
    platzhalter: str | None = None


class KartenAnfrage(BaseModel):
    profil: Profil
    gesehen: list[str] = []
    anzahl: int = Field(default=10, ge=1, le=30)


class KartenAntwort(BaseModel):
    karten: list[Karte]
    wird_duenn: bool
    tag_labels: dict[str, str]


class SammelPerson(BaseModel):
    id: str
    profil: Profil
    gesehen: list[str] = []


class KartenSammelAnfrage(BaseModel):
    personen: list[SammelPerson] = Field(min_length=2, max_length=12)
    anzahl: int = Field(default=12, ge=2, le=30)


class SammelKarte(BaseModel):
    fuer: str
    karte: Karte


class KartenSammelAntwort(BaseModel):
    karten: list[SammelKarte]
    duenn_fuer: list[str]
    tag_labels: dict[str, str]


class ProfilAusGespraechAnfrage(BaseModel):
    nachrichten: list[ChatNachricht]


class ProfilAendernAnfrage(BaseModel):
    profil: Profil
    anweisung: str
