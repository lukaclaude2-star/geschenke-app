from app.config import settings
from app.katalog.regeln import fasse_varianten_zusammen, pruefe_regeln
from app.katalog.verschlagworten import inhalts_hash, verschlagworte
from app.modelle import KatalogProdukt, QuellProdukt


async def baue_katalog(quellen: list[QuellProdukt],
                       alt: list[KatalogProdukt]) -> tuple[list[KatalogProdukt], dict[str, int]]:
    """Regeln → Varianten → Unverändertes wiederverwenden → Rest verschlagworten → Note filtern."""
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

    verschlagwortet = await verschlagworte(neu)
    alle = wiederverwendet + verschlagwortet
    katalog = sorted((p for p in alle if p.note >= settings.min_note), key=lambda p: p.id)
    bericht = {
        "quellen": len(quellen),
        "regel_raus": len(quellen) - len([p for p in quellen if pruefe_regeln(p) is None]),
        "wiederverwendet": len(wiederverwendet),
        "neu_verschlagwortet": len(verschlagwortet),
        "note_raus": len(alle) - len(katalog),
        "katalog": len(katalog),
    }
    return katalog, bericht
