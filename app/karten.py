from app.ideen import ideen_karten
from app.modelle import Karte, KartenAnfrage, KartenAntwort, KatalogProdukt
from app.ranking import waehle_karten
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
