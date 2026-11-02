# Geschenke-App Runde 3 – Bauplan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Lukas Runde-3-Wünsche umsetzen (Startseite B+D, Schriftgröße, schwarze Ränder,
270 Stichwörter mit Oberbereichen, Ideen für Wünsche ohne Produkte, 50 Nicht-Shopify-Shops,
Beispielbilder) – fertig zum Testen am iPhone am Morgen des 03.11.

**Architecture:** Server (FastAPI) bekommt Vokabular mit Oberbereichen, Ranking-Fallback,
Ideen-Reserve und Pexels-Bilder; ein neues Sammel-Skript füllt `katalog/quellen/`. Core
(Swift) bekommt Geburtstag, Anlass-Berechnung und Schriftstufe; die App eine neue Startseite.

**Tech Stack:** Python 3.12, FastAPI, pytest+respx, httpx; Swift 6.2 (CI), SwiftUI iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-02-geschenke-app-runde3-design.md`

## Global Constraints

- Antworten/Texte Deutsch mit echten Umlauten; Schlüssel (Tags) ASCII.
- Grundbausteine in `CLAUDE.md` gelten; Pexels-Schlüssel nur in Render (`PEXELS_KEY`).
- Keine Shopify-Shops; robots.txt wird beachtet.
- Alte gespeicherte App-Daten bleiben lesbar (`decodeIfPresent`).
- Server-Tests: `.venv/Scripts/python -m pytest -q`; Core-Tests nur in CI („iOS-Kern testen“).

## Review Focus

1. Profil mit Tag, den es nicht mehr gibt (alte Profile) → darf nichts kaputt machen.
2. Pexels down / kein Schlüssel / Kontingent leer → Karte ohne Bild, keine Fehlermeldung.
3. Shop liefert JSON-LD als Liste, @graph, AggregateOffer, Preis als String → wird gelesen.
4. Countdown am 24.12. selbst (0 Tage = „Heute“) und am 25.12. (nächstes Jahr).
5. Ausschluss trifft Oberbereich-Treffer / Ideen-Reserve → bleibt hart.

---

### Task 1: Vokabular mit Oberbereichen (Server)

**Files:** Modify `app/vokabular.py`, `app/katalog/verschlagworten.py`, `app/profil.py`,
`app/ideen.py`; Test `tests/test_vokabular.py`

**Produces:** `BEREICHE: dict[str, str]` (Schlüssel → Label), `THEMEN: dict[str, str]`,
`THEMA_BEREICH: dict[str, str]`, `LEBENSLAGEN` (18), `vokabular_text() -> str` (Themen
gruppiert nach Bereich für Prompts), `VOKABULAR_VERSION = 2`.

- [ ] Test: 270 Tags gesamt (252 Themen + 18 Lebenslagen), 22 Bereiche (inkl. Lebenslagen-Bereich
  nur als Gruppe), jedes Thema hat einen Bereich, alle Schlüssel `^[a-z0-9_]+$`, keine Duplikate,
  `grillen`, `gaming`, `heimwerken` vorhanden, `"🏅 Sport"`; `vokabular_text()` enthält
  `"grillen"`; `inhalts_hash` ändert sich mit `VOKABULAR_VERSION`.
- [ ] Rot sehen, umsetzen, grün; Prompts nutzen `vokabular_text()`. Commit.

### Task 2: Oberbereich-Fallback im Ranking

**Files:** `app/ranking.py`; Test `tests/test_ranking_bereich.py`

- [ ] Tests: Wunsch `whisky` (1.0), Produkt nur `wein` (gleicher Bereich) → Punkte 0.4;
  Produkt `whisky` → 1.0; Produkt aus anderem Bereich → nicht Kandidat; Produkt mit `whisky`
  und `wein` → 1.0 (kein Doppelzählen); unbekannter Wunsch-Tag → kein Absturz.
- [ ] `BEREICH_ANTEIL = 0.4`; umsetzen; Suite grün. Commit.

### Task 3: Ideen-Reserve für unterversorgte Wünsche

**Files:** `app/karten.py`, `app/ideen.py`; Test `tests/test_unterversorgt.py`

**Produces:** `unterversorgt(pool, profil) -> list[str]`; `ideen_karten(profil, anzahl,
gesehen, schwerpunkt: list[str] = [])` – Anfrage enthält `"schwerpunkt"`, Prompt verlangt
zuerst Ideen dazu.

- [ ] Tests: Profil kochen 1.0 + gaming 1.0, Katalog 12× kochen → `unterversorgt == ["gaming"]`;
  `karten_fuer` liefert ≤ 10 Produkte + Ideen, Ideen-Anfrage enthält `schwerpunkt: ["gaming"]`
  (respx); Wunsch mit Gewicht 0.3 zählt nicht; Sammelsuche nutzt dieselbe Reserve pro Person.
- [ ] Umsetzen; Suite grün. Commit.

### Task 4: Beispielbilder (Pexels)

**Files:** Create `app/bilder.py`; Modify `app/config.py` (`pexels_key: str = ""`),
`app/ideen.py`, `app/modelle.py` (`Karte.beispielbild: bool = False`), `render.yaml`;
Test `tests/test_bilder.py`

**Produces:** `async beispielbild(suchbegriff: str) -> str | None` (Cache im Speicher).

- [ ] Tests (respx): Treffer → `src.large`, Header `Authorization`; kein Schlüssel → None ohne
  Anfrage; 500/Timeout → None; zweiter Aufruf gleicher Begriff → keine zweite Anfrage;
  Ideenkarte mit Bild hat `bild_url` und `beispielbild=True`.
- [ ] Umsetzen; Suite grün. Commit.

### Task 5: Shop-Sammler (ohne Shopify)

**Files:** Create `scripts/sammle_shops.py`, `app/katalog/jsonld.py`, `katalog/shops.json`;
Test `tests/test_jsonld.py`

**Produces:** `produkte_aus_html(html, url, shop) -> list[QuellProdukt]`,
`ist_shopify(html, kopfzeilen) -> bool`, `urls_aus_sitemap(xml) -> (seiten, untersitemaps)`.

- [ ] Tests: JSON-LD Product direkt / in Liste / in `@graph` / `@type` als Liste; Offer-Liste,
  AggregateOffer(lowPrice), Preis "19,99" und "19.99"; Bild als str/Liste/ImageObject; ohne
  Preis oder Bild → nichts; Shopify erkannt an `cdn.shopify.com` oder Header `x-shopify-stage`;
  Sitemap-Index vs. URL-Set.
- [ ] Skript: robots.txt beachten, Sitemaps finden, Produkt-URLs stichprobenartig laden
  (≤ 120 Seiten/Shop, 0,5 s Pause), bis 30 Produkte je Shop → `katalog/quellen/shop-<slug>.json`;
  `--pruefe URL` meldet „lesbar/Shopify/blockiert“.
- [ ] Kandidaten prüfen, bis 47 neue lesbare Shops + 3 bestehende = 50. Sammeln, committen.

### Task 6: Katalog neu bauen

- [ ] `katalog.yml` timeout 120; lokal `python scripts/build_katalog.py` (Hintergrund);
  Bericht prüfen, `katalog/katalog.json` committen. Themenabdeckung je Bereich notieren.

### Task 7: Core – Geburtstag, Anlass, Schriftstufe

**Files:** `ios/GeschenkeCore/Sources/GeschenkeCore/AppDaten.swift`, Create `Anlass.swift`;
Test `Runde3Tests.swift`

**Produces:** `Geburtstag(tag:monat:)`; `GespeichertesProfil.geburtstag: Geburtstag?`;
`AppDaten.schriftgroesse: String = "normal"`; `Schriftstufe` (klein/normal/gross/sehrGross,
`titel`); `Anlass { art: .weihnachten | .geburtstag(UUID, String), tage: Int }`;
`naechsterAnlass(heute: Date, profile: [GespeichertesProfil], kalender: Calendar) -> Anlass`.

- [ ] Tests: alte JSON ohne Felder lesbar; 02.11. → Weihnachten 52; 24.12. → 0; 25.12. → 365;
  Geburtstag 14.11. → Geburtstag 12; Gleichstand → Geburtstag; 29.02. im Nicht-Schaltjahr.
- [ ] Umsetzen; CI „iOS-Kern testen“ grün. Commit.

### Task 8: App – Startseite, Schrift, Ränder, Stichwörter, Beispielbild

**Files:** `StartView.swift` (neu), `GeschenkeApp.swift`, `ProfilView.swift`, `ChatView.swift`,
`WischView.swift`, `KartenBild.swift`, `KartenView.swift`, Core `Modelle.swift`
(`Karte.beispielbild`), `.github/workflows/ios-build.yml` (Standard macos-15)

- [ ] Startseite nach Mockup `start-mix.html`; Einstellungen: Schriftgröße; Root
  `.dynamicTypeSize(...)`; ProfilView: Geburtstag (Tag/Monat, entfernbar); Chat: erkannte
  Stichwörter als Chips; WischView `.frame(maxWidth: .infinity, maxHeight: .infinity)`;
  Ideenkarte mit Bild zeigt „Beispielbild · Pexels“.
- [ ] iOS-Build auf macos-15 grün. Commit.

### Task 9: Review, Merge, Release, Übergabe

- [ ] Opus-Review des ganzen Zweigs, Fixes mit Tests; Merge nach main; Release-Build;
  Render-Deploy prüfen (`/karten` mit Gaming-Profil); Vault-Übergabe.
