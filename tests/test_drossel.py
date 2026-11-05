"""Drosselung je Verbindung (Plan 2026-11-05, Task 2)."""

from starlette.requests import Request

from app.drossel import Drossel, schluessel_fuer


class Uhr:
    def __init__(self, jetzt: float = 1_000_000.0):
        self.jetzt = jetzt

    def __call__(self) -> float:
        return self.jetzt


def anfrage(client_ip: str = "10.0.0.1", **kopf: str) -> Request:
    return Request({"type": "http", "method": "POST", "path": "/", "client": (client_ip, 1234),
                    "headers": [(k.replace("_", "-").encode(), v.encode()) for k, v in kopf.items()]})


def test_minute_grenze():
    uhr = Uhr(60 * 1000)
    d = Drossel(pro_minute=3, pro_tag=100, uhr=uhr)
    assert [d.erlaubt("a") for _ in range(4)] == [True, True, True, False]
    uhr.jetzt += 60
    assert d.erlaubt("a")


def test_tag_grenze():
    uhr = Uhr(86400 * 100)
    d = Drossel(pro_minute=100, pro_tag=5, uhr=uhr)
    ergebnisse = []
    for _ in range(6):
        ergebnisse.append(d.erlaubt("a"))
        uhr.jetzt += 61
    assert ergebnisse == [True] * 5 + [False]
    uhr.jetzt = 86400 * 101
    assert d.erlaubt("a")


def test_schluessel_getrennt():
    d = Drossel(pro_minute=1, pro_tag=100, uhr=Uhr())
    assert d.erlaubt("a")
    assert not d.erlaubt("a")
    assert d.erlaubt("b")


def test_speicher_begrenzt():
    uhr = Uhr()
    d = Drossel(pro_minute=5, pro_tag=100, max_schluessel=10, uhr=uhr)
    for i in range(20):
        assert d.erlaubt(f"k{i}")
    assert len(d._eintraege) <= 10


def test_zuruecksetzen():
    d = Drossel(pro_minute=1, pro_tag=100, uhr=Uhr())
    d.erlaubt("a")
    d.zuruecksetzen()
    assert d.erlaubt("a")


def test_cf_ip_vor_proxy_ip():
    # Hinter Render und Cloudflare haben alle Anfragen dieselbe Proxy-Adresse.
    a = schluessel_fuer(anfrage("10.0.0.1", cf_connecting_ip="203.0.113.5"))
    b = schluessel_fuer(anfrage("10.0.0.1", cf_connecting_ip="198.51.100.7"))
    assert a != b
    assert schluessel_fuer(anfrage("10.0.0.1", cf_connecting_ip="203.0.113.5")) == a


def test_true_client_ip_und_direkt():
    a = schluessel_fuer(anfrage("10.0.0.1", true_client_ip="203.0.113.5"))
    b = schluessel_fuer(anfrage("10.0.0.2"))
    c = schluessel_fuer(anfrage("10.0.0.3"))
    assert len({a, b, c}) == 3


def test_kein_klartext_ip():
    schluessel = schluessel_fuer(anfrage("10.0.0.1", cf_connecting_ip="203.0.113.5"))
    assert "203.0.113.5" not in schluessel
    assert "10.0.0.1" not in schluessel


def test_kosten_zaehlen_mehrfach():
    d = Drossel(pro_minute=10, pro_tag=100, uhr=Uhr())
    assert d.erlaubt("a", kosten=8)
    assert not d.erlaubt("a", kosten=3)
    assert d.erlaubt("a", kosten=2)
    assert not d.erlaubt("a")


def test_alte_tage_verfallen():
    # Datenschutzerklärung: Der Zähler verfällt spätestens nach einem Tag.
    uhr = Uhr(86400 * 100)
    d = Drossel(pro_minute=5, pro_tag=100, uhr=uhr)
    d.erlaubt("a")
    uhr.jetzt = 86400 * 101 + 5
    d.erlaubt("b")
    assert "a" not in d._eintraege


def test_grenzen_unter_dem_groq_kontingent():
    # Groq gratis: je Modell 1.000 Anfragen und 200.000 Token am Tag, für alle Nutzer zusammen.
    from app.config import Settings
    assert Settings.model_fields["drossel_pro_minute"].default <= 15
    assert Settings.model_fields["drossel_pro_tag"].default <= 200


def test_drossel_laeuft_auf_der_ereignisschleife():
    # Synchron liefe sie im Thread-Pool, und zwei Threads änderten gleichzeitig dasselbe Dict.
    import inspect

    from app import main
    assert inspect.iscoroutinefunction(main.drosseln)


def test_kosten_nicht_von_aussen_setzbar(client, auth, monkeypatch):
    from app import main
    monkeypatch.setattr(main, "DROSSEL", Drossel(pro_minute=1, pro_tag=100))
    leer = {"laenge": "normal", "nachrichten": []}
    status = [client.post("/chat/naechste?kosten=0", json=leer, headers=auth).status_code
              for _ in range(2)]
    assert status == [200, 429]


def test_route_429(client, auth, monkeypatch):
    from app import main
    monkeypatch.setattr(main, "DROSSEL", Drossel(pro_minute=2, pro_tag=100))
    leer = {"laenge": "normal", "nachrichten": []}
    status = [client.post("/chat/naechste", json=leer, headers=auth).status_code for _ in range(3)]
    assert status == [200, 200, 429]


def test_health_wird_nicht_gedrosselt(client, monkeypatch):
    from app import main
    monkeypatch.setattr(main, "DROSSEL", Drossel(pro_minute=1, pro_tag=1))
    assert [client.get("/health").status_code for _ in range(3)] == [200, 200, 200]
