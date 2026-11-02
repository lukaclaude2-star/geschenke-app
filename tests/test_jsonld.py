import json

from app.katalog.jsonld import ist_shopify, produkte_aus_html, urls_aus_sitemap


def seite(*bloecke) -> str:
    skripte = "".join(f'<script type="application/ld+json">{json.dumps(b)}</script>' for b in bloecke)
    return f"<html><head>{skripte}</head><body></body></html>"


PRODUKT = {
    "@context": "https://schema.org", "@type": "Product", "name": "Grillzange Edelstahl",
    "description": "<p>Lange Zange</p>", "image": "https://shop.de/zange.jpg", "sku": "Z-1",
    "offers": {"@type": "Offer", "price": "19.99", "priceCurrency": "EUR",
               "availability": "https://schema.org/InStock"},
}


def test_produkt_direkt():
    [p] = produkte_aus_html(seite(PRODUKT), "https://shop.de/p/zange", "Grillshop")
    assert p.titel == "Grillzange Edelstahl"
    assert p.preis == 19.99
    assert p.bild_url == "https://shop.de/zange.jpg"
    assert p.link == "https://shop.de/p/zange"
    assert p.shop == "Grillshop"
    assert p.beschreibung == "Lange Zange"
    assert p.id.startswith("grillshop-")
    assert p.lieferbar


def test_produkt_in_liste_und_graph():
    assert len(produkte_aus_html(seite([{"@type": "BreadcrumbList"}, PRODUKT]), "https://s.de/a", "S")) == 1
    graph = {"@context": "https://schema.org", "@graph": [{"@type": "WebPage"}, PRODUKT]}
    assert len(produkte_aus_html(seite(graph), "https://s.de/a", "S")) == 1
    mehrfach_typ = dict(PRODUKT, **{"@type": ["Product", "Thing"]})
    assert len(produkte_aus_html(seite(mehrfach_typ), "https://s.de/a", "S")) == 1


def test_preisformen():
    def preis(offers):
        [p] = produkte_aus_html(seite(dict(PRODUKT, offers=offers)), "https://s.de/a", "S")
        return p.preis
    assert preis([{"@type": "Offer", "price": 12}, {"@type": "Offer", "price": 15}]) == 12
    assert preis({"@type": "AggregateOffer", "lowPrice": "9,50", "highPrice": "20"}) == 9.5
    assert preis({"@type": "Offer", "price": "1.299,00"}) == 1299.0
    assert preis({"@type": "Offer", "priceSpecification": {"price": "7.5"}}) == 7.5


def test_bildformen():
    def bild(image):
        [p] = produkte_aus_html(seite(dict(PRODUKT, image=image)), "https://s.de/a", "S")
        return p.bild_url
    assert bild(["https://s.de/1.jpg", "https://s.de/2.jpg"]) == "https://s.de/1.jpg"
    assert bild({"@type": "ImageObject", "url": "https://s.de/3.jpg"}) == "https://s.de/3.jpg"
    assert bild("/bilder/4.jpg") == "https://s.de/bilder/4.jpg"


def test_ohne_preis_oder_bild_nichts():
    ohne_preis = dict(PRODUKT, offers={"@type": "Offer"})
    ohne_bild = {k: v for k, v in PRODUKT.items() if k != "image"}
    assert produkte_aus_html(seite(ohne_preis), "https://s.de/a", "S") == []
    assert produkte_aus_html(seite(ohne_bild), "https://s.de/a", "S") == []


def test_ausverkauft_und_kaputtes_json():
    aus = dict(PRODUKT, offers=dict(PRODUKT["offers"], availability="https://schema.org/OutOfStock"))
    [p] = produkte_aus_html(seite(aus), "https://s.de/a", "S")
    assert not p.lieferbar
    kaputt = '<script type="application/ld+json">{ kaputt </script>' + seite(PRODUKT)
    assert len(produkte_aus_html(kaputt, "https://s.de/a", "S")) == 1


def test_html_entities_im_titel():
    [p] = produkte_aus_html(seite(dict(PRODUKT, name="Salz &amp; Pfeffer")), "https://s.de/a", "S")
    assert p.titel == "Salz & Pfeffer"


def test_shopify_erkannt():
    assert ist_shopify('<script src="https://cdn.shopify.com/s/files/x.js">', {})
    assert ist_shopify("<html></html>", {"x-shopify-stage": "production"})
    assert ist_shopify("<html>Shopify.theme = {}</html>", {})
    assert not ist_shopify("<html>Shopware</html>", {"server": "nginx"})


def test_sitemap_index_und_urlset():
    index = """<?xml version="1.0"?><sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <sitemap><loc>https://s.de/sitemap-1.xml</loc></sitemap>
      <sitemap><loc> https://s.de/sitemap-2.xml </loc></sitemap></sitemapindex>"""
    assert urls_aus_sitemap(index) == ([], ["https://s.de/sitemap-1.xml", "https://s.de/sitemap-2.xml"])
    urlset = """<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url><loc>https://s.de/a</loc></url><url><loc>https://s.de/b</loc></url></urlset>"""
    assert urls_aus_sitemap(urlset) == (["https://s.de/a", "https://s.de/b"], [])
    assert urls_aus_sitemap("kein xml <<<") == ([], [])


MICRODATA = """<html><head>
<meta property="og:title" content="Grillhandschuh Leder &amp; Kevlar">
<meta property="og:image" content="https://shop.de/handschuh.jpg">
<meta property="og:description" content="Hitzefest bis 300 Grad">
<meta property="product:price:amount" content="24.90">
</head><body><div itemscope itemtype="https://schema.org/Product">
<span itemprop="name">Grillhandschuh</span>
<meta itemprop="price" content="24.90"><link itemprop="availability" href="https://schema.org/InStock">
</div></body></html>"""


def test_microdata_und_meta_als_ersatz():
    [p] = produkte_aus_html(MICRODATA, "https://shop.de/detail/1", "Grillshop")
    assert p.titel == "Grillhandschuh Leder & Kevlar"
    assert p.preis == 24.9
    assert p.bild_url == "https://shop.de/handschuh.jpg"
    assert p.beschreibung == "Hitzefest bis 300 Grad"
    assert p.lieferbar


def test_microdata_ohne_preis_nichts_und_kategorieseite_nichts():
    ohne_preis = MICRODATA.replace('<meta property="product:price:amount" content="24.90">', "") \
                          .replace('<meta itemprop="price" content="24.90">', "")
    assert produkte_aus_html(ohne_preis, "https://shop.de/a", "S") == []
    kategorie = '<html><meta property="og:title" content="Grills"><meta property="og:image" content="/a.jpg"></html>'
    assert produkte_aus_html(kategorie, "https://shop.de/a", "S") == []


def test_kategorieseite_mit_mehreren_produkt_kaesten_nichts():
    kaesten = "".join(f'<div itemscope itemtype="https://schema.org/Product"><span itemprop="name">Grill {i}</span>'
                      f'<meta itemprop="price" content="{i}99.00"></div>' for i in (4, 5))
    seite_ = ('<html><meta property="og:title" content="Gasgrills | Shop">'
              '<meta property="og:image" content="/k.jpg">' + kaesten + "</html>")
    assert produkte_aus_html(seite_, "https://shop.de/gasgrills/", "S") == []


def test_mehrere_jsonld_produkte_mit_verschiedenen_namen_nichts():
    zwei = seite(PRODUKT, dict(PRODUKT, name="Grillbürste"))
    assert produkte_aus_html(zwei, "https://shop.de/zubehoer/", "S") == []
    gleiche = seite(PRODUKT, dict(PRODUKT))  # z. B. Varianten desselben Produkts
    assert len(produkte_aus_html(gleiche, "https://shop.de/p/zange", "S")) == 1


def test_microdata_name_nicht_von_der_marke():
    marke = ('<html><meta property="og:image" content="/t.jpg"><h1 class="x">Schreibtisch Tojo Stand</h1>'
             '<div itemscope itemtype="https://schema.org/Product">'
             '<div itemprop="brand" itemscope itemtype="https://schema.org/Brand"><meta itemprop="name" content="Tojo"></div>'
             '<meta itemprop="price" content="309.00"></div></html>')
    [p] = produkte_aus_html(marke, "https://shop.de/p/1", "S")
    assert p.titel == "Schreibtisch Tojo Stand"


def test_tausenderpunkt_ohne_nachkommastellen():
    def preis(wert):
        [p] = produkte_aus_html(seite(dict(PRODUKT, offers={"@type": "Offer", "price": wert})), "https://s.de/a", "S")
        return p.preis
    assert preis("12.500") == 12500.0
    assert preis("19.99") == 19.99


def test_slug_mit_umlauten():
    from app.katalog.jsonld import _slug
    assert _slug("Grillfürst") == "grillfuerst"
    assert _slug("Krämer Pferdesport") == "kraemer-pferdesport"
    assert _slug("Wolle Rödel") == "wolle-roedel"
    assert _slug("Fuß") == "fuss"
