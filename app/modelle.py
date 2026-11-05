import html
import re
from typing import Literal

from pydantic import BaseModel, Field, field_validator

# Grenzen gegen Missbrauch (Plan 2026-11-05). Zu lange Texte und Listen werden gekürzt statt
# abgelehnt: Ein eingefügter Roman oder ein über Monate gewachsenes Profil soll die App nicht
# kaputtmachen, nur die KI nicht mit beliebig viel Text füttern.
MAX_TEXT = 2000
MAX_GESEHEN = 10_000
MAX_NACHRICHTEN = 60


def gekuerzt(wert, laenge: int = MAX_TEXT):
    return wert[:laenge] if isinstance(wert, str) else wert


def letzte_gesehen(wert):
    return wert[-MAX_GESEHEN:] if isinstance(wert, list) else wert


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

    _zusammenfassung_kuerzen = field_validator("zusammenfassung", mode="before")(gekuerzt)


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
    # Partnerlink mit Provision: Die App zeigt „Anzeige“ (app/partnerlinks.py).
    anzeige: bool = False


class ChatNachricht(BaseModel):
    rolle: Literal["app", "nutzer"]
    text: str

    _text_kuerzen = field_validator("text", mode="before")(gekuerzt)


class ChatAnfrage(BaseModel):
    laenge: Literal["schnell", "normal", "gruendlich"]
    nachrichten: list[ChatNachricht] = Field(max_length=MAX_NACHRICHTEN)


class ChatAntwort(BaseModel):
    fertig: bool
    frage: str | None = None
    platzhalter: str | None = None


class KartenAnfrage(BaseModel):
    profil: Profil
    gesehen: list[str] = []
    anzahl: int = Field(default=10, ge=1, le=30)

    _gesehen_kuerzen = field_validator("gesehen", mode="before")(letzte_gesehen)


class KartenAntwort(BaseModel):
    karten: list[Karte]
    wird_duenn: bool
    tag_labels: dict[str, str]


class SammelPerson(BaseModel):
    id: str = Field(max_length=100)
    profil: Profil
    gesehen: list[str] = []

    _gesehen_kuerzen = field_validator("gesehen", mode="before")(letzte_gesehen)


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
    nachrichten: list[ChatNachricht] = Field(max_length=MAX_NACHRICHTEN)


class ProfilAendernAnfrage(BaseModel):
    profil: Profil
    anweisung: str

    _anweisung_kuerzen = field_validator("anweisung", mode="before")(gekuerzt)
