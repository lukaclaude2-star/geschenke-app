from app.modelle import Ausschluss, KatalogProdukt, Profil, Wunsch
from app.ranking import bewerte, ist_ausgeschlossen, waehle_karten


def produkt(id: str, themen=("garten",), **abweichung) -> KatalogProdukt:
    werte = dict(
        id=id, titel=f"Produkt {id}", beschreibung="Eine schöne Beschreibung", preis=25.0,
        bild_url="https://x/b.jpg", link=f"https://x/{id}", shop="Shop",
        themen=list(themen), lebenslagen=[], farben=[], eigenschaften=[],
        persoenlich=False, note=8, inhalts_hash="h",
    )
    werte.update(abweichung)
    return KatalogProdukt(**werte)


def profil(wuensche=(("garten", 1.0),), ausschluesse=(), budget_max=None) -> Profil:
    return Profil(
        zusammenfassung="Oma",
        wuensche=[Wunsch(tag=t, label=t, gewicht=g) for t, g in wuensche],
        ausschluesse=[Ausschluss(schluessel=s, label=s) for s in ausschluesse],
        budget_max=budget_max,
    )


def aus(*schluessel):
    return [Ausschluss(schluessel=s, label=s) for s in schluessel]


def test_farbe_ausgeschlossen_ueber_feld():
    assert ist_ausgeschlossen(produkt("a", farben=["schwarz"]), aus("farbe:schwarz"))


def test_farbe_ausgeschlossen_ueber_titelwort():
    assert ist_ausgeschlossen(produkt("a", titel="Schwarzer Becher"), aus("farbe:schwarz"))


def test_farbe_weiss_ueber_titel_mit_eszett():
    assert ist_ausgeschlossen(produkt("a", titel="Weiße Tasse"), aus("farbe:weiss"))


def test_wort_ausschluss_freitext():
    p = produkt("a", titel="Tasse mit Katzen-Motiv")
    assert ist_ausgeschlossen(p, aus("wort:katze"))


def test_wort_ausschluss_in_beschreibung():
    p = produkt("a", beschreibung="Mit Rum verfeinert")
    assert ist_ausgeschlossen(p, aus("wort:rum"))


def test_thema_und_eigenschaft_ausschluss():
    assert ist_ausgeschlossen(produkt("a", themen=["wein"]), aus("thema:wein"))
    assert ist_ausgeschlossen(produkt("b", eigenschaften=["alkohol"]), aus("eigenschaft:alkohol"))


def test_nicht_ausgeschlossen():
    assert not ist_ausgeschlossen(produkt("a"), aus("farbe:schwarz", "wort:katze"))


def test_bewerte_summiert_gewichte_und_persoenlich():
    p = produkt("a", themen=["garten", "krimis"], persoenlich=True)
    assert bewerte(p, profil((("garten", 1.0), ("krimis", 0.5)))) == 1.7


def test_ausschluss_gilt_auch_fuer_schwache_treffer():
    katalog = [produkt("schwach", farben=["schwarz"])]
    karten, _ = waehle_karten(katalog, profil((("garten", 0.5),), ["farbe:schwarz"]), set(), 10)
    assert karten == []


def test_budget_ist_hart():
    katalog = [produkt("teuer", preis=60.0), produkt("ok", preis=50.0)]
    karten, _ = waehle_karten(katalog, profil(budget_max=50.0), set(), 10)
    assert [k.id for k in karten] == ["ok"]


def test_ohne_budget_kein_preisfilter():
    karten, _ = waehle_karten([produkt("teuer", preis=999.0)], profil(), set(), 10)
    assert [k.id for k in karten] == ["teuer"]


def test_gesehene_kommen_nicht_wieder():
    karten, _ = waehle_karten([produkt("a"), produkt("b")], profil(), {"a"}, 10)
    assert [k.id for k in karten] == ["b"]


def test_hoeheres_gewicht_zuerst():
    katalog = [produkt("g", themen=["garten"]), produkt("k", themen=["krimis"])]
    karten, _ = waehle_karten(katalog, profil((("garten", 1.0), ("krimis", 1.8))), set(), 10)
    assert [k.id for k in karten] == ["k", "g"]


def test_abwechslung_gleiches_thema_wird_abgewertet():
    katalog = [produkt("g1", themen=["garten"]), produkt("g2", themen=["garten"]),
               produkt("k", themen=["krimis"])]
    karten, _ = waehle_karten(katalog, profil((("garten", 1.2), ("krimis", 1.0))), set(), 10)
    assert [k.id for k in karten][:2] == ["g1", "k"]


def test_bewertung_null_wird_nie_gezeigt():
    karten, _ = waehle_karten([produkt("fremd", themen=["gaming"])], profil(), set(), 10)
    assert karten == []


def test_anzahl_wird_eingehalten_und_nicht_duenn():
    katalog = [produkt(str(i)) for i in range(15)]
    karten, duenn = waehle_karten(katalog, profil(), set(), 10)
    assert len(karten) == 10 and duenn is False


def test_schwache_treffer_nach_guten_und_wird_duenn():
    katalog = [produkt("gut", themen=["garten"]), produkt("schwach", themen=["krimis"])]
    karten, duenn = waehle_karten(katalog, profil((("garten", 1.0), ("krimis", 0.4))), set(), 10)
    assert [k.id for k in karten] == ["gut", "schwach"] and duenn is True


def test_budget_unter_allen_preisen_liefert_leer_und_wird_duenn():
    karten, duenn = waehle_karten([produkt("a", preis=25.0)], profil(budget_max=5.0), set(), 10)
    assert karten == [] and duenn is True


def test_alle_gewichte_null_liefert_leer_und_wird_duenn():
    karten, duenn = waehle_karten([produkt("a")], profil((("garten", 0.0),)), set(), 10)
    assert karten == [] and duenn is True


def test_ranking_kennt_kein_provisionsfeld():
    assert not [f for f in KatalogProdukt.model_fields if "provision" in f]
