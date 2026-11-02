"""Welche Karten in welcher Reihenfolge kommen.

Ausschlüsse und Budget sind harte Filter (Grundbaustein 3). Produkte ohne jeden Bezug
zur Person werden nie gezeigt (Grundbaustein 5). Provision spielt keine Rolle (Grundbaustein 4).
"""

import re

from app.config import settings
from app.modelle import Ausschluss, KatalogProdukt, Profil
from app.vokabular import FARB_LABELS

GUT_AB = 1.0
PERSOENLICH_BONUS = 0.2
ABWECHSLUNGS_ABZUG = 0.3


def _farbe_im_text(farbe: str, text: str) -> bool:
    woerter = {farbe, FARB_LABELS.get(farbe, farbe).lower()}
    return any(re.search(r"\b" + re.escape(w), text) for w in woerter)


def ist_ausgeschlossen(p: KatalogProdukt, ausschluesse: list[Ausschluss]) -> bool:
    titel = p.titel.lower()
    text = f"{titel} {p.beschreibung.lower()}"
    for a in ausschluesse:
        art, _, wert = a.schluessel.partition(":")
        wert = wert.strip().lower()
        if not wert:
            continue
        if art == "thema" and (wert in p.themen or wert in p.lebenslagen):
            return True
        if art == "farbe" and (wert in p.farben or _farbe_im_text(wert, titel)):
            return True
        if art == "eigenschaft" and wert in p.eigenschaften:
            return True
        if art == "wort" and wert in text:
            return True
    return False


def bewerte(p: KatalogProdukt, profil: Profil) -> float:
    tags = set(p.themen) | set(p.lebenslagen)
    punkte = sum(w.gewicht for w in profil.wuensche if w.tag in tags)
    if punkte > 0 and p.persoenlich:
        punkte += PERSOENLICH_BONUS
    return round(punkte, 6)


def _erstes_thema(p: KatalogProdukt) -> str | None:
    return p.themen[0] if p.themen else None


def _gierig(pool: list[tuple[float, KatalogProdukt]], gewaehlt: list[KatalogProdukt], anzahl: int) -> None:
    rest = list(pool)
    while rest and len(gewaehlt) < anzahl:
        def effektiv(eintrag: tuple[float, KatalogProdukt]) -> float:
            punkte, p = eintrag
            gleich = sum(1 for g in gewaehlt if _erstes_thema(g) == _erstes_thema(p))
            return punkte - ABWECHSLUNGS_ABZUG * gleich
        bester = max(rest, key=effektiv)  # max nimmt bei Gleichstand den ersten → stabil
        rest.remove(bester)
        gewaehlt.append(bester[1])


def waehle_karten(katalog: list[KatalogProdukt], profil: Profil, gesehen: set[str],
                  anzahl: int) -> tuple[list[KatalogProdukt], bool]:
    gut: list[tuple[float, KatalogProdukt]] = []
    schwach: list[tuple[float, KatalogProdukt]] = []
    for p in katalog:
        if p.note < settings.min_note:  # Grundbaustein 4, auch wenn der Katalog es schon filtert
            continue
        if p.id in gesehen or ist_ausgeschlossen(p, profil.ausschluesse):
            continue
        if profil.budget_max is not None and p.preis > profil.budget_max:
            continue
        punkte = bewerte(p, profil)
        if punkte >= GUT_AB:
            gut.append((punkte, p))
        elif punkte > 0:
            schwach.append((punkte, p))
    gewaehlt: list[KatalogProdukt] = []
    _gierig(gut, gewaehlt, anzahl)
    _gierig(schwach, gewaehlt, anzahl)
    return gewaehlt, len(gut) < anzahl
