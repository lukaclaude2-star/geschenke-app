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
    alle = wiederverwendet + verschlagwortet
    # Auch abgelehnte Produkte bleiben mit ihrer Note gespeichert: So werden sie nicht jeden
    # Tag neu bewertet (spart Kontingent) und rutschen nicht durch eine zufällig bessere Note durch.
    katalog = sorted(alle, key=lambda p: p.id)
    zeigbar = [p for p in katalog if p.note >= settings.min_note]
    bericht = {
        "quellen": len(quellen),
        "regel_raus": len(quellen) - len([p for p in quellen if pruefe_regeln(p) is None]),
        "wiederverwendet": len(wiederverwendet),
        "neu_verschlagwortet": len(verschlagwortet),
        "note_raus": len(katalog) - len(zeigbar),
        "katalog": len(zeigbar),
    }
    return katalog, bericht
