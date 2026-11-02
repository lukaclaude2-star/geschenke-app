import math

from app.ideen import ideen_karten
from app.modelle import (Karte, KartenAnfrage, KartenAntwort, KartenSammelAnfrage, KartenSammelAntwort,
                         KatalogProdukt, SammelKarte)
from app.ranking import kandidaten, waehle_aus, waehle_karten
from app.vokabular import tag_label


def produkt_zu_karte(p: KatalogProdukt) -> Karte:
    return Karte(
        id=p.id, art="produkt", titel=p.titel, preis=p.preis, bild_url=p.bild_url,
        shop=p.shop, link=p.link, tags=p.themen + p.lebenslagen,
    )


async def karten_fuer(katalog: list[KatalogProdukt], anfrage: KartenAnfrage) -> KartenAntwort:
    gesehen = set(anfrage.gesehen)
    produkte, wird_duenn = waehle_karten(katalog, anfrage.profil, gesehen, anfrage.anzahl)
    karten = [produkt_zu_karte(p) for p in produkte]
    fehlend = anfrage.anzahl - len(karten)
    if wird_duenn and fehlend > 0:
        karten += await ideen_karten(anfrage.profil, fehlend, gesehen)
    karten = [k for k in karten if k.link]  # Grundbaustein 2: ohne Link keine Karte
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
    stapel: list[list[Karte]] = []
    duenn_fuer: list[str] = []
    for i, (person, pool) in enumerate(zip(personen, pools)):
        eigene = [(punkte, p) for punkte, p in pool if beste[p.id][1] == i]
        produkte, duenn = waehle_aus(eigene, anteil)
        karten = [produkt_zu_karte(p) for p in produkte]
        if duenn:
            duenn_fuer.append(person.id)
            fehlend = anteil - len(karten)
            if fehlend > 0:
                karten += await ideen_karten(person.profil, fehlend, set(person.gesehen))
        stapel.append([k for k in karten if k.link])  # Grundbaustein 2

    ergebnis: list[SammelKarte] = []
    vergeben: set[str] = set()
    for runde in range(anteil):
        for person, karten in zip(personen, stapel):
            if runde < len(karten) and len(ergebnis) < anfrage.anzahl and karten[runde].id not in vergeben:
                vergeben.add(karten[runde].id)
                ergebnis.append(SammelKarte(fuer=person.id, karte=karten[runde]))
    labels = {t: tag_label(t) for k in ergebnis for t in k.karte.tags}
    return KartenSammelAntwort(karten=ergebnis, duenn_fuer=duenn_fuer, tag_labels=labels)
