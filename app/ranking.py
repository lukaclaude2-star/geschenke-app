"""Welche Karten in welcher Reihenfolge kommen.

Ausschlüsse und Budget sind harte Filter (Grundbaustein 3). Produkte ohne jeden Bezug
zur Person werden nie gezeigt (Grundbaustein 5). Provision spielt keine Rolle (Grundbaustein 4).
"""

import re
from functools import lru_cache

from app.config import settings
from app.modelle import Ausschluss, KatalogProdukt, Profil
from app.vokabular import EIGENSCHAFT_MUSTER, FARB_LABELS, THEMA_BEREICH, THEMA_GRUPPE, mit_gruppen

GUT_AB = 1.0
PERSOENLICH_BONUS = 0.2
ABWECHSLUNGS_ABZUG = 0.3
BEREICH_ANTEIL = 0.4
# Gleiche Gruppe (Stiefel-Wunsch, Sneaker-Produkt): näher als nur der gleiche Bereich.
GRUPPE_ANTEIL = 0.7


@lru_cache(maxsize=None)
def _klein(titel: str, beschreibung: str) -> tuple[str, str]:
    """Titel und Titel+Beschreibung klein – einmal je Produkt statt bei jeder Anfrage."""
    titel = titel.lower()
    return titel, f"{titel} {beschreibung.lower()}"


@lru_cache(maxsize=4096)
def _muster(art: str, wert: str) -> re.Pattern | None:
    """Ein vorkompilierter Regex je Ausschluss; Eigenschaften mit allen Wörtern in einem Durchlauf."""
    if art == "thema":
        woerter = [re.escape(wert.replace("_", " "))]
    elif art == "farbe":
        woerter = [re.escape(w) for w in {wert, FARB_LABELS.get(wert, wert).lower()}]
    elif art == "eigenschaft":
        woerter = list(EIGENSCHAFT_MUSTER.get(wert, ()))
    else:
        return None
    return re.compile(r"\b(?:" + "|".join(woerter) + ")") if woerter else None


def _trifft(art: str, wert: str, text: str) -> bool:
    muster = _muster(art, wert)
    return muster is not None and muster.search(text) is not None


def ist_ausgeschlossen(p: KatalogProdukt, ausschluesse: list[Ausschluss]) -> bool:
    """Hart: Tags UND Text werden geprüft, damit ein Ausschluss nicht allein an der KI hängt."""
    titel, text = _klein(p.titel, p.beschreibung)
    for a in ausschluesse:
        art, _, wert = a.schluessel.partition(":")
        wert = wert.strip().lower()
        if not wert:
            continue
        if art == "thema" and (wert in mit_gruppen(p.themen) or wert in p.lebenslagen
                               or _trifft(art, wert, text)):
            return True
        if art == "farbe" and (wert in p.farben or _trifft(art, wert, titel)):
            return True
        if art == "eigenschaft" and (wert in p.eigenschaften or _trifft(art, wert, text)):
            return True
        if art == "wort" and wert in text:
            return True
    return False


def bewerte(p: KatalogProdukt, profil: Profil) -> float:
    """Direkte Treffer zählen voll (ein Stiefel ist auch ein direkter Treffer für „schuhe“). Ohne
    direkten Treffer zählt erst die Gruppe (Stiefel-Wunsch → Sneaker), dann der Oberbereich – und
    dann nur der stärkste Wunsch mal BEREICH_ANTEIL, damit sich verwandte Wünsche (grillen,
    kochen, backen) nicht zu einem Wert über echten Treffern aufsummieren."""
    tags = mit_gruppen(p.themen) | set(p.lebenslagen)
    punkte = sum(w.gewicht for w in profil.wuensche if w.tag in tags)
    if punkte == 0:
        punkte = max((w.gewicht * GRUPPE_ANTEIL for w in profil.wuensche
                      if THEMA_GRUPPE.get(w.tag) in tags), default=0.0)
    if punkte == 0:
        bereiche = {THEMA_BEREICH[t] for t in p.themen if t in THEMA_BEREICH}
        punkte = max((w.gewicht * BEREICH_ANTEIL for w in profil.wuensche
                      if THEMA_BEREICH.get(w.tag) in bereiche), default=0.0)
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


def im_budget(preis: float, profil: Profil) -> bool:
    if profil.budget_min is not None and preis < profil.budget_min:
        return False
    return profil.budget_max is None or preis <= profil.budget_max


def kandidaten(katalog: list[KatalogProdukt], profil: Profil,
               gesehen: set[str]) -> list[tuple[float, KatalogProdukt]]:
    """Alle Produkte, die diese Person sehen darf und die zu ihr passen – Katalogreihenfolge."""
    ergebnis: list[tuple[float, KatalogProdukt]] = []
    for p in katalog:
        if p.note < settings.min_note:  # Grundbaustein 4, auch wenn der Katalog es schon filtert
            continue
        if p.id in gesehen or ist_ausgeschlossen(p, profil.ausschluesse):
            continue
        if not im_budget(p.preis, profil):
            continue
        punkte = bewerte(p, profil)
        if punkte > 0:
            ergebnis.append((punkte, p))
    return ergebnis


def waehle_aus(pool: list[tuple[float, KatalogProdukt]], anzahl: int) -> tuple[list[KatalogProdukt], bool]:
    """Erst gute, dann schwache Treffer, jeweils mit Abwechslung; True = es wird dünn."""
    gut = [e for e in pool if e[0] >= GUT_AB]
    schwach = [e for e in pool if e[0] < GUT_AB]
    gewaehlt: list[KatalogProdukt] = []
    _gierig(gut, gewaehlt, anzahl)
    _gierig(schwach, gewaehlt, anzahl)
    return gewaehlt, len(gut) < anzahl


def waehle_karten(katalog: list[KatalogProdukt], profil: Profil, gesehen: set[str],
                  anzahl: int) -> tuple[list[KatalogProdukt], bool]:
    return waehle_aus(kandidaten(katalog, profil, gesehen), anzahl)
