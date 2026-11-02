from app.config import settings
from app.katalog.regeln import fasse_varianten_zusammen, pruefe_regeln
from app.katalog.verschlagworten import inhalts_hash, verschlagworte
from app.modelle import KatalogProdukt, QuellProdukt


async def baue_katalog(quellen: list[QuellProdukt],
                       alt: list[KatalogProdukt],
                       pause_sekunden: float = 0) -> tuple[list[KatalogProdukt], dict[str, int]]:
    """Regeln → Varianten → Unverändertes wiederverwenden → Rest verschlagworten.

    Liefert alle verschlagworteten Produkte; gezeigt wird nur, was zeigbar() durchlässt."""
    bestanden = [p for p in quellen if pruefe_regeln(p) is None]
    bestanden = fasse_varianten_zusammen(bestanden)

    alt_nach_id = {p.id: p for p in alt}
    wiederverwendet: list[KatalogProdukt] = []
    neu: list[QuellProdukt] = []
    for p in bestanden:
        vorher = alt_nach_id.get(p.id)
        if vorher is not None and vorher.inhalts_hash == inhalts_hash(p):
            wiederverwendet.append(vorher)
        else:
            neu.append(p)

    verschlagwortet = await verschlagworte(neu, pause_sekunden)
    # Scheitert die KI (z. B. Tageskontingent leer), bleibt der alte Eintrag stehen – mit altem
    # Hash, damit der nächste Lauf es erneut versucht. So schrumpft der Katalog nie über Nacht.
    geschafft = {p.id for p in verschlagwortet}
    offen = [p for p in neu if p.id not in geschafft]
    behalten = [alt_nach_id[p.id] for p in offen if p.id in alt_nach_id]
    alle = wiederverwendet + verschlagwortet + behalten
    # Auch abgelehnte Produkte bleiben mit ihrer Note gespeichert: So werden sie nicht jeden
    # Tag neu bewertet (spart Kontingent) und rutschen nicht durch eine zufällig bessere Note durch.
    katalog = sorted(alle, key=lambda p: p.id)
    zeigbar = [p for p in katalog if p.note >= settings.min_note]
    bericht = {
        "quellen": len(quellen),
        "regel_raus": len(quellen) - len([p for p in quellen if pruefe_regeln(p) is None]),
        "wiederverwendet": len(wiederverwendet),
        "neu_verschlagwortet": len(verschlagwortet),
        "noch_offen": len(offen),
        "note_raus": len(katalog) - len(zeigbar),
        "katalog": len(zeigbar),
    }
    return katalog, bericht
