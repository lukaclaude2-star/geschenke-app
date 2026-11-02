"""Welche Karten in welcher Reihenfolge kommen.

Ausschlüsse und Budget sind harte Filter (Grundbaustein 3). Produkte ohne jeden Bezug
zur Person werden nie gezeigt (Grundbaustein 5). Provision spielt keine Rolle (Grundbaustein 4).
"""

import re

from app.config import settings
from app.modelle import Ausschluss, KatalogProdukt, Profil
from app.vokabular import EIGENSCHAFT_MUSTER, FARB_LABELS, THEMA_BEREICH

GUT_AB = 1.0
PERSOENLICH_BONUS = 0.2
ABWECHSLUNGS_ABZUG = 0.3
BEREICH_ANTEIL = 0.4


def _farbe_im_text(farbe: str, text: str) -> bool:
    woerter = {farbe, FARB_LABELS.get(farbe, farbe).lower()}
    return any(re.search(r"\b" + re.escape(w), text) for w in woerter)


def _wort_im_text(muster: str, text: str) -> bool:
    return re.search(r"\b" + muster, text) is not None


def ist_ausgeschlossen(p: KatalogProdukt, ausschluesse: list[Ausschluss]) -> bool:
    """Hart: Tags UND Text werden geprüft, damit ein Ausschluss nicht allein an der KI hängt."""
    titel = p.titel.lower()
    text = f"{titel} {p.beschreibung.lower()}"
    for a in ausschluesse:
        art, _, wert = a.schluessel.partition(":")
        wert = wert.strip().lower()
        if not wert:
            continue
        if art == "thema" and (wert in p.themen or wert in p.lebenslagen
                               or _wort_im_text(re.escape(wert.replace("_", " ")), text)):
            return True
        if art == "farbe" and (wert in p.farben or _farbe_im_text(wert, titel)):
            return True
        if art == "eigenschaft" and (wert in p.eigenschaften or any(
                _wort_im_text(m, text) for m in EIGENSCHAFT_MUSTER.get(wert, ()))):
            return True
        if art == "wort" and wert in text:
            return True
    return False


def bewerte(p: KatalogProdukt, profil: Profil) -> float:
    """Direkte Treffer zählen voll. Nur ohne jeden direkten Treffer zählt der Oberbereich – und
    dann nur der stärkste Wunsch mal BEREICH_ANTEIL, damit sich verwandte Wünsche (grillen,
    kochen, backen) nicht zu einem Wert über echten Treffern aufsummieren."""
    tags = set(p.themen) | set(p.lebenslagen)
    punkte = sum(w.gewicht for w in profil.wuensche if w.tag in tags)
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
