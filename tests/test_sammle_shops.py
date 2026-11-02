from scripts.sammle_shops import _kandidaten


def test_nur_seiten_der_deutschen_sprachversion():
    seiten = ["https://www.11teamsports.com/it-it/scarpe/p/1", "https://www.11teamsports.com/de-de/schuhe/p/2",
              "https://www.11teamsports.com/DE-DE/ball/p/3"]
    assert sorted(_kandidaten(seiten, "https://www.11teamsports.com/de-de/")) == [
        "https://www.11teamsports.com/DE-DE/ball/p/3", "https://www.11teamsports.com/de-de/schuhe/p/2"]


def test_ohne_sprachpfad_alles_vom_shop():
    seiten = ["https://shop.de/a", "https://andererhost.de/b", "https://shop.de/bild.jpg"]
    assert _kandidaten(seiten, "https://www.shop.de/") == ["https://shop.de/a"]
