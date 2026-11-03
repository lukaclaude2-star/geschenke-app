from scripts.sammle_shops import _kandidaten


def test_nur_seiten_der_deutschen_sprachversion():
    seiten = ["https://www.11teamsports.com/it-it/scarpe/p/1", "https://www.11teamsports.com/de-de/schuhe/p/2",
              "https://www.11teamsports.com/DE-DE/ball/p/3"]
    assert sorted(_kandidaten(seiten, "https://www.11teamsports.com/de-de/")) == [
        "https://www.11teamsports.com/DE-DE/ball/p/3", "https://www.11teamsports.com/de-de/schuhe/p/2"]


def test_ohne_sprachpfad_alles_vom_shop():
    seiten = ["https://shop.de/a", "https://andererhost.de/b", "https://shop.de/bild.jpg"]
    assert _kandidaten(seiten, "https://www.shop.de/") == ["https://shop.de/a"]


def test_ohne_sprachpfad_keine_fremdsprachigen_seiten():
    """Deutsch ohne Präfix, andere Sprachen unter /en/, /fr/ … (z. B. VBS Hobby, Rosen Tantau)."""
    seiten = ["https://shop.de/rose-1", "https://shop.de/en/rose-2", "https://shop.de/fr-fr/rose-3",
              "https://shop.de/de/rose-4", "https://shop.de/eng/rose-5"]
    assert sorted(_kandidaten(seiten, "https://www.shop.de/")) == [
        "https://shop.de/de/rose-4", "https://shop.de/eng/rose-5", "https://shop.de/rose-1"]
