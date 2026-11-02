import asyncio
import math

from app.ideen import ideen_karten
from app.modelle import (Karte, KartenAnfrage, KartenAntwort, KartenSammelAnfrage, KartenSammelAntwort,
                         KatalogProdukt, Profil, SammelKarte)
from app.ranking import kandidaten, waehle_aus
from app.vokabular import tag_label


def produkt_zu_karte(p: KatalogProdukt) -> Karte:
    return Karte(
        id=p.id, art="produkt", titel=p.titel, preis=p.preis, bild_url=p.bild_url,
        shop=p.shop, link=p.link, tags=p.themen + p.lebenslagen,
    )


UNTERVERSORGT_AB_GEWICHT = 0.5
UNTERVERSORGT_UNTER = 3
IDEEN_JE_LUECKE = 2


def unterversorgt(pool: list[tuple[float, KatalogProdukt]], profil: Profil) -> list[str]:
    """Wünsche, zu denen es (fast) keine direkt passenden Produkte gibt – z. B. Gaming."""
    luecken: list[str] = []
    for w in profil.wuensche:
        if w.gewicht < UNTERVERSORGT_AB_GEWICHT or w.tag in luecken:
            continue
        treffer = sum(1 for _, p in pool if w.tag in p.themen or w.tag in p.lebenslagen)
        if treffer < UNTERVERSORGT_UNTER:
            luecken.append(w.tag)
    return luecken


def _mische(produkte: list[Karte], ideen: list[Karte]) -> list[Karte]:
    """Nach je zwei Produkten eine Idee – so taucht der fehlende Wunsch früh auf."""
    ergebnis: list[Karte] = []
    ideen = list(ideen)
    for i, karte in enumerate(produkte):
        ergebnis.append(karte)
        if i % 2 == 1 and ideen:
            ergebnis.append(ideen.pop(0))
    return ergebnis + ideen


async def stapel_fuer(pool: list[tuple[float, KatalogProdukt]], profil: Profil, anzahl: int,
                      gesehen: set[str]) -> tuple[list[Karte], bool]:
    """Produkte plus Ideenkarten: Ideen füllen auf, wenn es dünn wird, und bekommen reservierte
    Plätze für Wünsche ohne passende Produkte. Fällt die KI aus, füllen weitere Produkte auf."""
    alle, wird_duenn = waehle_aus(pool, anzahl)
    luecken = unterversorgt(pool, profil)
    reserve = min(anzahl // 2, IDEEN_JE_LUECKE * len(luecken))
    produkte = alle[:anzahl - reserve]
    fehlend = anzahl - len(produkte)
    ideen: list[Karte] = []
    if (wird_duenn or luecken) and fehlend > 0:
        ideen = [k for k in await ideen_karten(profil, fehlend, gesehen, luecken) if k.link]
    nachschub = alle[len(produkte):len(produkte) + max(0, fehlend - len(ideen))]
    karten = _mische([produkt_zu_karte(p) for p in produkte + nachschub], ideen)
    return [k for k in karten if k.link], wird_duenn  # Grundbaustein 2: ohne Link keine Karte


async def karten_fuer(katalog: list[KatalogProdukt], anfrage: KartenAnfrage) -> KartenAntwort:
    gesehen = set(anfrage.gesehen)
    pool = kandidaten(katalog, anfrage.profil, gesehen)
    karten, wird_duenn = await stapel_fuer(pool, anfrage.profil, anfrage.anzahl, gesehen)
    labels = {t: tag_label(t) for k in karten for t in k.tags}
    return KartenAntwort(karten=karten, wird_duenn=wird_duenn, tag_labels=labels)


async def sammel_karten_fuer(katalog: list[KatalogProdukt], anfrage: KartenSammelAnfrage) -> KartenSammelAntwort:
    """Ein Stapel für mehrere Personen. Ausschlüsse, Budget und Gesehenes gelten pro Person
    (gleicher Code wie /karten); jedes Produkt geht an die Person, zu der es am besten passt."""
    personen = anfrage.personen
    pools = [kandidaten(katalog, p.profil, set(p.gesehen)) for p in personen]

    beste: dict[str, tuple[float, int]] = {}
    for i, pool in enumerate(pools):
        for punkte, produkt in pool:
            if produkt.id not in beste or punkte > beste[produkt.id][0]:
                beste[produkt.id] = (punkte, i)

    anteil = math.ceil(anfrage.anzahl / len(personen))
    auftraege = []
    for i, (person, pool) in enumerate(zip(personen, pools)):
        eigene = [(punkte, p) for punkte, p in pool if beste[p.id][1] == i]
        # Lücken zählen an den zugeteilten Produkten: was an jemand anderen ging, sieht diese Person nicht.
        auftraege.append(stapel_fuer(eigene, person.profil, anteil, set(person.gesehen)))
    # Gleichzeitig statt nacheinander: jede KI-Abfrage kann bis zu 45 s dauern, die App wartet 90 s.
    ergebnisse = await asyncio.gather(*auftraege)
    stapel = [karten for karten, _ in ergebnisse]
    duenn_fuer = [person.id for person, (_, duenn) in zip(personen, ergebnisse) if duenn]

    ergebnis: list[SammelKarte] = []
    vergeben: set[str] = set()
    for runde in range(anteil):
        for person, karten in zip(personen, stapel):
            if runde < len(karten) and len(ergebnis) < anfrage.anzahl and karten[runde].id not in vergeben:
                vergeben.add(karten[runde].id)
                ergebnis.append(SammelKarte(fuer=person.id, karte=karten[runde]))
    labels = {t: tag_label(t) for k in ergebnis for t in k.karte.tags}
    return KartenSammelAntwort(karten=ergebnis, duenn_fuer=duenn_fuer, tag_labels=labels)
