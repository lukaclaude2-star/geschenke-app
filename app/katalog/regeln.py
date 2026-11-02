"""Ramsch-Filter Stufe 1: feste Regeln ohne KI (Grundbaustein 4)."""

from app.config import settings
from app.modelle import QuellProdukt

GESPERRTE_KATEGORIEN = (
    "ersatzteil", "druckerpatrone", "toner", "kabel", "medikament", "arznei", "hygiene", "erotik",
)


def pruefe_regeln(p: QuellProdukt) -> str | None:
    """Grund, warum das Produkt rausfliegt – oder None, wenn es besteht."""
    if not p.link:
        return "kein Link"
    if not p.bild_url:
        return "kein Bild"
    if p.bild_breite is not None and p.bild_breite < settings.min_bildbreite:
        return "Bild zu klein"
    if len(p.beschreibung.strip()) < settings.min_beschreibung:
        return "Beschreibung zu kurz"
    if p.preis < settings.min_preis:
        return "zu billig"
    if not p.lieferbar:
        return "nicht lieferbar"
    kategorie = p.kategorie.lower()
    for gesperrt in GESPERRTE_KATEGORIEN:
        if gesperrt in kategorie:
            return f"gesperrte Kategorie ({gesperrt})"
    return None


def fasse_varianten_zusammen(ps: list[QuellProdukt]) -> list[QuellProdukt]:
    """Varianten einer Gruppe werden eine Karte: die günstigste bleibt, am Platz der ersten."""
    ergebnis: list[QuellProdukt] = []
    platz_der_gruppe: dict[str, int] = {}
    for p in ps:
        gruppe = p.varianten_gruppe
        if not gruppe:
            ergebnis.append(p)
            continue
        if gruppe not in platz_der_gruppe:
            platz_der_gruppe[gruppe] = len(ergebnis)
            ergebnis.append(p)
        elif p.preis < ergebnis[platz_der_gruppe[gruppe]].preis:
            ergebnis[platz_der_gruppe[gruppe]] = p
    return ergebnis
