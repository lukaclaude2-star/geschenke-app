# Geschenke-App v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Erste, nur für Luka testbare Version: Gespräch über die beschenkte Person → harte Ausschlüsse + gewichtete Schlagwörter → endlos wischbare, echte Produkte aus einem gefilterten, KI-verschlagworteten Testkatalog → Merkliste mit Links; Profile freiwillig, per Chat änderbar.

**Architecture:** Python-Server (FastAPI, Render Free) hält den Katalog als JSON im Speicher, spricht mit Groq (Modell-Kette wie beim Wecker) und rankt Karten. Ein Skript baut den Katalog aus Feed-artigen Quelldateien (Ramsch-Filter Stufe 1 + KI-Note/Schlagwörter Stufe 2) und läuft täglich per GitHub Actions. Die iPhone-App (SwiftUI) hält Profile, Merkliste und gelernte Gewichtung lokal; die testbare Logik liegt im Paket `GeschenkeCore` (nur Foundation, Linux-Tests).

**Tech Stack:** Python 3.12, FastAPI, httpx, pydantic-settings, pytest, respx · Swift 6 Toolchain im Swift-5-Sprachmodus, SwiftUI, iOS 26, XcodeGen · GitHub Actions (macOS-Build unsigniert, Linux-Tests, Katalog-Cron) · Groq · Render Free · SideStore.

**Spec:** `docs/superpowers/specs/2026-11-02-geschenke-app-design.md` — und die **Grundbausteine in `CLAUDE.md`**, gegen die jede Aufgabe geprüft wird.

**Vorlage:** Das Wecker-Repo `C:\Claude\Wecker` löst dieselben Probleme (Groq-Kette `app/brain/groq.py`, `render.yaml`, `ios/project.yml`, `.github/workflows/ios-build.yml`, `ios-core-tests.yml`). Abschreiben ist ausdrücklich erwünscht; Vault-Notizen `Wissen/iphone-apps-ohne-mac` und `Wissen/gratis-llm-apis` lesen.

## Global Constraints

- Alle Texte in der App auf Deutsch mit echten Umlauten und ß.
- JSON zwischen App und Server: Schlüssel in `snake_case`, Swift mit **expliziten `CodingKeys`** (keine `keyDecodingStrategy`).
- Gewichte liegen immer im Bereich **0.0–2.0**, Standard **1.0**.
- Ramsch-Grenzwerte (einstellbar in `app/config.py`): **Mindestpreis 8.0 €**, **Mindest-Geschenk-Note 6** (Skala 1–10), Mindestlänge Beschreibung **60 Zeichen**, Mindestbildbreite **300 px** (nur geprüft, wenn bekannt).
- Gesperrte Kategorien (Teilwort, klein geschrieben): `ersatzteil`, `druckerpatrone`, `toner`, `kabel`, `medikament`, `arznei`, `hygiene`, `erotik`.
- Gesprächslängen = KI-Fragen zwischen fester erster Frage und fester Schlussfrage: **schnell 0–1, normal 1–3, gruendlich 2–6** (≈ 3 / 5 / 8 Fragen gesamt).
- Feste Texte: erste Frage **„Für wen suchst du ein Geschenk?“** (Platzhalter „z. B. meine Oma, 70, hat gerade mit Gärtnern angefangen“); Schlussfrage **„Gibt es sonst noch etwas, das ich wissen sollte?“** (Platzhalter „z. B. sie mag kein Schwarz, hat schon alle Harry-Potter-Bücher“).
- Ausschlüsse sind hart: Kein Code-Pfad (schwache Treffer, Ideenkarten, Gewichtung) darf ein ausgeschlossenes Produkt liefern.
- Provision/Shop-Vergütung ist **kein** Feld im Ranking.
- Keine Karte ohne `link`.
- Geheimnisse (`GROQ_API_KEY`, `APP_TOKEN`) nur in Render-Umgebung bzw. GitHub-Secrets, nie im Repo. Die App bekommt `APP_TOKEN` beim CI-Build über eine Build-Einstellung ins Info.plist.
- An Groq geht nur Gesprächs-/Produkttext, keine Gerätekennung.
- Farben: Hintergrund `#11131C`, Karte `#1C1F2B`, Rand `#2C3040`, Gold `#E0B84C`, Text `#EEEEEE`.
- iOS-Ziel 26.0, Bundle-ID `de.luka.geschenke`, Anzeigename „Geschenke“ (Arbeitstitel).

## Review Focus

1. **Ausschluss als Freitext, den das Vokabular nicht kennt** („nichts mit Katzen-Motiv“): muss trotzdem wirken (Wort-Ausschluss über Titel + Beschreibung) → Test in Task 6.
2. **Sehr kurze oder leere Antworten im Gespräch** („weiß nicht“, „“): das Gespräch läuft weiter und endet regulär, kein Absturz, kein Endlos-Nachfragen → Test in Task 7.
3. **KI liefert kaputtes JSON oder unbekannte Schlagwörter**: nächster Versuch/nächstes Modell; unbekannte Schlagwörter werden verworfen, nie durchgereicht → Tests in Task 3, 5, 8.
4. **Server schläft (Render-Kaltstart bis ~1 min) oder ist offline**: App zeigt „Server wacht auf …“ und bietet „Nochmal“, statt zu hängen → Test in Task 10.
5. **Budget unter allen Katalogpreisen oder alle Regler auf 0**: keine leere Ansicht ohne Erklärung — `wird_duenn = true`, Ideenkarten oder Hinweis „Für <Name> wird's langsam dünn“ → Tests in Task 6 und 9.

---

### Task 1: Repo, Server-Skelett, Token-Schutz

**Files:**
- Create: `.gitignore`, `requirements.txt`, `requirements-dev.txt`, `pytest.ini`, `render.yaml`, `app/__init__.py`, `app/config.py`, `app/main.py`, `tests/__init__.py`, `tests/conftest.py`, `tests/test_api_basis.py`, `README.md`

**Interfaces:**
- Produces: `app.config.settings` (pydantic-settings) mit `app_token: str`, `groq_api_key: str`, `ki_modelle: list[str]` (Standard wie Wecker `chat_models`), `katalog_pfad: str = "katalog/katalog.json"`, `amazon_tag: str = ""`, `min_preis: float = 8.0`, `min_note: int = 6`, `min_beschreibung: int = 60`, `min_bildbreite: int = 300`. `app.main.app` (FastAPI). `app.main.pruefe_token(authorization: str | None) -> None` (wirft 401). Test-Fixture `client` (TestClient mit `APP_TOKEN=test`) und `auth = {"Authorization": "Bearer test"}` in `conftest.py`.

- [ ] **Step 1:** `git init` in `C:\Claude\Apps\geschenke-app`, Branch `main`; erster Commit nur mit `docs/`, `CLAUDE.md`, `.gitignore` (enthält `.superpowers/`, `.env`, `__pycache__/`, `.venv/`, `ios/*.xcodeproj`, `ios/build/`). Danach Branch `app/v1` für alle weiteren Tasks. **GitHub-Repo erst nach Lukas Okay anlegen** (`gh repo create geschenke-app --private --source . --push`).
- [ ] **Step 2: Failing tests** in `tests/test_api_basis.py`:

```python
def test_health_ohne_token(client):
    assert client.get("/health").json() == {"ok": True}

def test_geschuetzte_route_ohne_token_401(client):
    assert client.post("/chat/naechste", json={}).status_code == 401

def test_falscher_token_401(client):
    r = client.post("/chat/naechste", json={}, headers={"Authorization": "Bearer falsch"})
    assert r.status_code == 401
```

- [ ] **Step 3:** `pytest -q` → FAIL (kein Modul `app.main`).
- [ ] **Step 4:** Implementieren. Versionen in `requirements.txt` fest wie im Wecker (fastapi, uvicorn[standard], httpx, pydantic-settings). `/chat/naechste` darf hier noch ein Platzhalter sein, der nach `pruefe_token` 501 liefert. `render.yaml` wie Wecker, Dienstname `geschenke`, envVars `APP_TOKEN` und `GROQ_API_KEY` mit `sync: false`.
- [ ] **Step 5:** `pytest -q` → PASS.
- [ ] **Step 6: Commit** `feat: Server-Skelett mit Token-Schutz`

---

### Task 2: Vokabular und Datenmodelle

**Files:**
- Create: `app/vokabular.py`, `app/modelle.py`, `tests/test_vokabular.py`

**Interfaces:**
- Produces (`app/vokabular.py`):
  - `THEMEN: dict[str, str]` — id → Label mit Emoji, mind. 40 Einträge, u. a. `garten` „🌱 Garten“, `lesen`, `krimis`, `kochen`, `backen`, `gaming`, `musik`, `sport`, `fitness`, `wandern`, `outdoor`, `camping`, `angeln`, `fahrrad`, `laufen`, `yoga`, `wellness`, `reisen`, `fotografie`, `kunst`, `basteln`, `handarbeit`, `technik`, `film`, `tiere`, `hund`, `katze`, `tee`, `kaffee`, `wein`, `mode`, `schmuck`, `deko`, `wohnen`, `pflanzen`, `kinder`, `spiele`, `puzzle`, `sprachen`, `geschichte`.
  - `LEBENSLAGEN: dict[str, str]` — u. a. `umzug`, `rente`, `abi`, `studium`, `baby`, `hochzeit`, `neuer_job`, `geburtstag_rund`. Kombinationen („Rente + Garten“) entstehen aus Thema + Lage, nie als eigener Eintrag.
  - `FARBEN: tuple[str, ...]` — `schwarz, weiss, grau, rot, rosa, orange, gelb, gruen, blau, lila, braun, gold, silber, bunt`.
  - `EIGENSCHAFTEN: dict[str, str]` — `alkohol`, `suessigkeiten`, `lebensmittel`, `leder`, `plastik`, `duft`, `tierprodukt`, `elektronik`.
  - `ist_gueltiger_ausschluss(schluessel: str) -> bool` — gültig sind `thema:<THEMEN-id>`, `farbe:<FARBEN>`, `eigenschaft:<EIGENSCHAFTEN-id>`, `wort:<beliebiger nichtleerer Text>`.
  - `label_fuer(schluessel: str) -> str` — z. B. `farbe:schwarz` → „Schwarz“, `wort:katzen` → „„katzen““.
- Produces (`app/modelle.py`, pydantic):
  - `QuellProdukt(id: str, titel: str, beschreibung: str, preis: float, bild_url: str | None, bild_breite: int | None = None, link: str, shop: str, kategorie: str = "", lieferbar: bool = True, farbe: str | None = None, varianten_gruppe: str | None = None)`
  - `KatalogProdukt(QuellProdukt + themen: list[str], lebenslagen: list[str], farben: list[str], eigenschaften: list[str], persoenlich: bool, note: int, inhalts_hash: str)`
  - `Wunsch(tag: str, label: str, gewicht: float)`, `Ausschluss(schluessel: str, label: str)`
  - `Profil(zusammenfassung: str, wuensche: list[Wunsch], ausschluesse: list[Ausschluss], budget_max: float | None = None)` — `tag` eines Wunsches ist eine THEMEN- **oder** LEBENSLAGEN-id.
  - `Karte(id: str, art: Literal["produkt","idee"], titel: str, preis: float | None, preis_von: float | None, preis_bis: float | None, bild_url: str | None, emoji: str | None, shop: str, link: str, tags: list[str])`
  - `ChatNachricht(rolle: Literal["app","nutzer"], text: str)`, `ChatAnfrage(laenge: Literal["schnell","normal","gruendlich"], nachrichten: list[ChatNachricht])`, `ChatAntwort(fertig: bool, frage: str | None, platzhalter: str | None)`
  - `KartenAnfrage(profil: Profil, gesehen: list[str], anzahl: int = 10)`, `KartenAntwort(karten: list[Karte], wird_duenn: bool, tag_labels: dict[str, str])` — `tag_labels` enthält das Label jedes Tags, der in `karten` vorkommt (die App braucht es für neu gelernte Wünsche)
  - `ProfilAendernAnfrage(profil: Profil, anweisung: str)`

- [ ] **Step 1: Failing tests:** `test_themen_ids_sind_klein_und_ohne_leerzeichen`, `test_mindestens_40_themen`, `test_ausschluss_gueltig` (`thema:garten`, `farbe:schwarz`, `eigenschaft:alkohol`, `wort:katzen` → True; `farbe:kariert`, `thema:unbekannt`, `wort:`, `xyz` → False), `test_label_fuer_farbe` (`farbe:schwarz` → „Schwarz“), `test_wunsch_tag_teilt_keine_id_zwischen_themen_und_lebenslagen` (Schnittmenge leer).
- [ ] **Step 2:** `pytest tests/test_vokabular.py -q` → FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: Vokabular und Datenmodelle`

---

### Task 3: KI-Client mit Modell-Kette (JSON-Antworten)

**Files:**
- Create: `app/ki.py`, `tests/test_ki.py`

**Interfaces:**
- Produces: `async def frage_json(system: str, nutzer: str, *, client: httpx.AsyncClient | None = None, max_tokens: int = 1500) -> dict` und `class KiUeberlastet(RuntimeError)`.
- Verhalten wie `C:\Claude\Wecker\app\brain\groq.py`, aber ohne Werkzeuge: `response_format: {"type": "json_object"}`, gpt-oss mit `reasoning_effort: "low"`, sonst `reasoning_format: "hidden"`. Nächstes Modell bei Status 404/429/5xx **und** bei leerer Antwort oder nicht parsebarem JSON (pro Modell 2 Versuche). Alle Modelle erschöpft → `KiUeberlastet`.

- [ ] **Step 1: Failing tests** (respx mockt `https://api.groq.com/openai/v1/chat/completions`): `test_liefert_geparstes_json`, `test_429_wechselt_auf_naechstes_modell` (zweiter Aufruf trägt `model == settings.ki_modelle[1]`), `test_kaputtes_json_wird_wiederholt_dann_naechstes_modell`, `test_alle_modelle_erschoepft_wirft_kiueberlastet`, `test_schickt_keine_geraetekennung` (Request-Body enthält nur `model, messages, temperature, max_tokens, response_format` + Reasoning-Feld).
- [ ] **Step 2:** → FAIL. **Step 3:** implementieren. **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: Groq-Client mit Modell-Kette`

---

### Task 4: Ramsch-Filter Stufe 1 und Varianten

**Files:**
- Create: `app/katalog/__init__.py`, `app/katalog/regeln.py`, `tests/test_regeln.py`

**Interfaces:**
- Produces: `pruefe_regeln(p: QuellProdukt) -> str | None` (Grund als kurzer deutscher Text oder `None` = besteht); `fasse_varianten_zusammen(ps: list[QuellProdukt]) -> list[QuellProdukt]` (gleiche `varianten_gruppe` → eine Karte: das günstigste Produkt bleibt; ohne Gruppe unverändert; Reihenfolge der ersten Vorkommen bleibt).

- [ ] **Step 1: Failing tests** (Hilfsfunktion `gut(**abweichung)` baut ein bestehendes Produkt mit Preis 25.0, Beschreibung 80 Zeichen, Bild, Link):

```python
def test_gutes_produkt_besteht(): assert pruefe_regeln(gut()) is None
def test_ohne_bild(): assert pruefe_regeln(gut(bild_url=None))
def test_bild_zu_klein(): assert pruefe_regeln(gut(bild_breite=200))
def test_bildbreite_unbekannt_besteht(): assert pruefe_regeln(gut(bild_breite=None)) is None
def test_beschreibung_zu_kurz(): assert pruefe_regeln(gut(beschreibung="Toller Becher"))
def test_unter_mindestpreis(): assert pruefe_regeln(gut(preis=7.99))
def test_genau_mindestpreis_besteht(): assert pruefe_regeln(gut(preis=8.0)) is None
def test_nicht_lieferbar(): assert pruefe_regeln(gut(lieferbar=False))
def test_gesperrte_kategorie_teilwort(): assert pruefe_regeln(gut(kategorie="Elektronik > USB-Kabel"))
def test_ohne_link(): assert pruefe_regeln(gut(link=""))
def test_varianten_behalten_guenstigste():
    a = gut(id="a", preis=30, varianten_gruppe="kissen"); b = gut(id="b", preis=20, varianten_gruppe="kissen")
    assert [p.id for p in fasse_varianten_zusammen([a, b, gut(id="c")])] == ["b", "c"]
```

- [ ] **Step 2:** → FAIL. **Step 3:** implementieren (Grenzwerte aus `settings`). **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: Ramsch-Filter Stufe 1`

---

### Task 5: Stufe 2 (KI-Note, Schlagwörter) und Katalog-Bau

**Files:**
- Create: `app/katalog/verschlagworten.py`, `app/katalog/bauen.py`, `app/katalog/laden.py`, `scripts/build_katalog.py`, `tests/test_verschlagworten.py`, `tests/test_bauen.py`

**Interfaces:**
- Consumes: `frage_json` (Task 3), `pruefe_regeln`, `fasse_varianten_zusammen` (Task 4), Vokabular (Task 2).
- Produces:
  - `inhalts_hash(p: QuellProdukt) -> str` (sha256 über titel, beschreibung, preis, kategorie, farbe).
  - `async def verschlagworte(ps: list[QuellProdukt]) -> list[KatalogProdukt]` — Stapel zu 10 Produkten pro KI-Aufruf. Prompt verlangt je Produkt `{"id","themen","lebenslagen","farben","eigenschaften","persoenlich","note"}` nur aus dem Vokabular; Note = „Würde man das verschenken?“ 1–10, No-Name-Ramsch mit vollgestopften Titeln niedrig. Unbekannte ids werden verworfen. Ist `p.farbe` gesetzt und im Vokabular, steht sie immer in `farben`. Fehlt ein Produkt in der Antwort, wird es ausgelassen (nächster Lauf versucht es erneut).
  - `async def baue_katalog(quellen: list[QuellProdukt], alt: list[KatalogProdukt]) -> tuple[list[KatalogProdukt], dict[str, int]]` — Regeln → Varianten → Produkte mit unverändertem `inhalts_hash` aus `alt` wiederverwenden → Rest verschlagworten → `note < settings.min_note` raus. Bericht-Zähler: `quellen`, `regel_raus`, `wiederverwendet`, `neu_verschlagwortet`, `note_raus`, `katalog`.
  - `lade_katalog(pfad: str) -> list[KatalogProdukt]` (fehlende Datei → `[]`).
  - CLI `python scripts/build_katalog.py` liest alle `katalog/quellen/*.json` (Liste von QuellProdukt), schreibt `katalog/katalog.json` (UTF-8, `ensure_ascii=False`, sortiert nach id) und druckt den Bericht.

- [ ] **Step 1: Failing tests** (KI per Monkeypatch auf `frage_json`): `test_unbekannte_themen_werden_verworfen`, `test_feed_farbe_landet_immer_in_farben`, `test_fehlendes_produkt_in_ki_antwort_wird_ausgelassen`, `test_stapel_zu_zehn` (23 Produkte → 3 Aufrufe), `test_note_unter_6_fliegt_raus`, `test_unveraendertes_produkt_wird_nicht_neu_verschlagwortet` (KI-Fake zählt Aufrufe: 0), `test_geaendertes_produkt_wird_neu_verschlagwortet`, `test_regel_raus_wird_nicht_an_ki_geschickt`, `test_bericht_zaehlt_richtig`.
- [ ] **Step 2:** → FAIL. **Step 3:** implementieren. **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: KI-Verschlagwortung und Katalog-Bau`

---

### Task 6: Ranking und harte Ausschlüsse

**Files:**
- Create: `app/ranking.py`, `tests/test_ranking.py`

**Interfaces:**
- Consumes: `KatalogProdukt`, `Profil` (Task 2).
- Produces:
  - `ist_ausgeschlossen(p: KatalogProdukt, ausschluesse: list[Ausschluss]) -> bool` — `thema:x` trifft `x in p.themen`; `farbe:x` trifft `x in p.farben`; `eigenschaft:x` trifft `x in p.eigenschaften`; `wort:x` trifft, wenn `x` (klein geschrieben) in `titel` oder `beschreibung` (klein) vorkommt. Zusätzlich: `farbe:x` trifft auch, wenn das Farbwort (Label, klein) im Titel steht.
  - `bewerte(p: KatalogProdukt, profil: Profil) -> float` — Summe der Gewichte aller Wünsche, deren `tag` in `p.themen` oder `p.lebenslagen` steht; `+0.2`, wenn `p.persoenlich`.
  - `waehle_karten(katalog: list[KatalogProdukt], profil: Profil, gesehen: set[str], anzahl: int) -> tuple[list[KatalogProdukt], bool]`:

```text
kandidaten = katalog ohne gesehen, ohne ist_ausgeschlossen, mit preis <= budget_max (falls gesetzt)
gut     = kandidaten mit bewerte >= 1.0      schwach = kandidaten mit 0 < bewerte < 1.0
Auswahl gierig nach Punkten, zuerst aus gut, dann aus schwach:
  effektiv = bewerte - 0.3 * (Anzahl bereits gewählter Karten mit gleichem ersten Thema)
wird_duenn = (len(gut) < anzahl)
Produkte mit bewerte == 0 werden nie gezeigt (sonst „beliebig“).
```

- [ ] **Step 1: Failing tests:** `test_farbe_ausgeschlossen_ueber_feld`, `test_farbe_ausgeschlossen_ueber_titelwort` („Schwarzer Becher“ + `farbe:schwarz`), `test_wort_ausschluss_freitext` (Review Focus 1: `wort:katze` schließt „Tasse mit Katzen-Motiv“ aus), `test_ausschluss_gilt_auch_fuer_schwache_treffer`, `test_budget_ist_hart`, `test_ohne_budget_kein_preisfilter`, `test_gesehene_kommen_nicht_wieder`, `test_hoeheres_gewicht_zuerst`, `test_abwechslung_gleiches_thema_wird_abgewertet`, `test_bewertung_null_wird_nie_gezeigt`, `test_budget_unter_allen_preisen_liefert_leer_und_wird_duenn` (Review Focus 5), `test_alle_gewichte_null_liefert_leer_und_wird_duenn` (Review Focus 5), `test_ranking_kennt_kein_provisionsfeld` (`KatalogProdukt.model_fields` enthält kein Feld mit „provision“).
- [ ] **Step 2:** → FAIL. **Step 3:** implementieren. **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: Ranking mit harten Ausschlüssen`

---

### Task 7: Gespräch `/chat/naechste`

**Files:**
- Create: `app/gespraech.py`, `tests/test_gespraech.py`
- Modify: `app/main.py` (Route)

**Interfaces:**
- Consumes: `frage_json`, `ChatAnfrage`, `ChatAntwort`.
- Produces: `ERSTE_FRAGE`, `ERSTER_PLATZHALTER`, `SCHLUSSFRAGE`, `SCHLUSS_PLATZHALTER` (Texte aus Global Constraints), `KI_FRAGEN: dict[str, tuple[int, int]] = {"schnell": (0, 1), "normal": (1, 3), "gruendlich": (2, 6)}`, `async def naechster_schritt(a: ChatAnfrage) -> ChatAntwort`. Route `POST /chat/naechste` (Token).

```text
keine Nachrichten                        → ERSTE_FRAGE (kein KI-Aufruf)
letzte App-Nachricht == SCHLUSSFRAGE und Nutzer hat geantwortet → fertig=True
k = Anzahl App-Nachrichten - 1 (bisher gestellte KI-Fragen); (min, max) = KI_FRAGEN[laenge]
k >= max                                  → SCHLUSSFRAGE (kein KI-Aufruf)
sonst KI: {"genug": bool, "frage": str, "platzhalter": str}
  Prompt: wie ein Freund; eine Frage; ausführliche Antworten → genauer nachhaken,
  knappe Antworten → eher genug; vage Antwort → einmal konkret nachfragen;
  platzhalter beginnt mit „z. B.“ und passt zu den bisherigen Antworten.
k >= min und genug                        → SCHLUSSFRAGE
sonst                                     → KI-Frage + Platzhalter
KiUeberlastet                             → SCHLUSSFRAGE (Gespräch endet sauber statt zu hängen)
```

- [ ] **Step 1: Failing tests** (KI gefakt): `test_start_liefert_erste_frage_ohne_ki`, `test_schnell_nach_max_eine_ki_frage_kommt_schlussfrage`, `test_gruendlich_ignoriert_genug_vor_minimum`, `test_normal_genug_nach_minimum_fuehrt_zur_schlussfrage`, `test_antwort_auf_schlussfrage_ist_fertig`, `test_kurze_und_leere_antworten_brechen_nichts` (Review Focus 2: Antworten „“ und „weiß nicht“, KI sagt nie „genug“ → spätestens nach `max` kommt die Schlussfrage, danach `fertig`), `test_ki_ueberlastet_fuehrt_zur_schlussfrage`, `test_route_braucht_token`.
- [ ] **Step 2:** → FAIL. **Step 3:** implementieren. **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: Gespräch mit anpassbarer Länge`

---

### Task 8: Profil aus Gespräch und Profil per Chat ändern

**Files:**
- Create: `app/profil.py`, `tests/test_profil.py`
- Modify: `app/main.py` (Routen)

**Interfaces:**
- Consumes: `frage_json`, Vokabular, Modelle.
- Produces: `bereinige_profil(roh: dict) -> Profil` (verwirft unbekannte Tags und ungültige Ausschlüsse, setzt Labels aus dem Vokabular, klemmt Gewichte auf 0.0–2.0, fehlendes Gewicht → 1.0, doppelte Tags zusammengefasst mit höherem Gewicht); `async def profil_aus_gespraech(nachrichten: list[ChatNachricht]) -> Profil`; `async def profil_aendern(profil: Profil, anweisung: str) -> Profil`. Routen `POST /profil/aus-gespraech` (Body `{"nachrichten": [...]}`) und `POST /profil/aendern` (`ProfilAendernAnfrage`), beide mit Token, `KiUeberlastet` → HTTP 503 `{"fehler": "ki_ueberlastet"}`.
- Prompt-Regeln: Wünsche nur aus THEMEN/LEBENSLAGEN, Gewicht 0.5–1.5 nach Wichtigkeit; alles, was die Person nicht mag/nicht darf, als Ausschluss (`farbe:`/`eigenschaft:`/`thema:`; sonst `wort:` mit dem kürzesten treffenden Wortstamm, z. B. „katze“); `budget_max` als Zahl oder null; `zusammenfassung` ein Satz. Beim Ändern bleiben nicht erwähnte Wünsche/Ausschlüsse unverändert.

- [ ] **Step 1: Failing tests:** `test_bereinigen_verwirft_unbekannte_tags`, `test_bereinigen_klemmt_gewichte`, `test_bereinigen_verwirft_ungueltige_ausschluesse`, `test_bereinigen_setzt_labels`, `test_aus_gespraech_nutzt_ki_und_bereinigt`, `test_aendern_schickt_altes_profil_und_anweisung_mit`, `test_ki_ueberlastet_gibt_503`.
- [ ] **Step 2:** → FAIL. **Step 3:** implementieren. **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: Profil aus Gespräch und per Chat ändern`

---

### Task 9: Karten-Route mit Ideenkarten

**Files:**
- Create: `app/karten.py`, `app/ideen.py`, `tests/test_karten.py`
- Modify: `app/main.py` (Katalog beim Start laden, Route)

**Interfaces:**
- Consumes: `lade_katalog`, `waehle_karten`, `ist_ausgeschlossen`, `frage_json`.
- Produces: `produkt_zu_karte(p: KatalogProdukt) -> Karte` (`art="produkt"`, `tags = p.themen + p.lebenslagen`); `async def ideen_karten(profil: Profil, anzahl: int) -> list[Karte]` — KI liefert `{"ideen": [{"titel","emoji","preis_von","preis_bis","suchbegriff","themen"}]}`; Link `https://www.amazon.de/s?k=<url-kodierter suchbegriff>` plus `&tag=<amazon_tag>`, wenn gesetzt; `id = "idee:" + suchbegriff`; verworfen wird jede Idee, deren Titel/Suchbegriff einen `wort:`- oder Farb-Ausschluss trifft, deren `themen` ein `thema:`-Ausschluss trifft oder deren `preis_bis > budget_max`. `KiUeberlastet` → `[]`. Route `POST /karten` (`KartenAnfrage` → `KartenAntwort`, Token): Produkte aus `waehle_karten`; fehlen Karten zur `anzahl` und `wird_duenn`, mit Ideenkarten auffüllen (bereits `gesehen`e Ideen-ids nicht wiederholen).

- [ ] **Step 1: Failing tests:** `test_karte_hat_immer_link`, `test_genug_produkte_keine_ki`, `test_wird_duenn_fuellt_mit_ideen_auf`, `test_idee_mit_ausgeschlossenem_wort_wird_verworfen`, `test_idee_ueber_budget_wird_verworfen`, `test_idee_link_mit_und_ohne_amazon_tag`, `test_ki_ueberlastet_liefert_nur_produkte_und_wird_duenn`, `test_tag_labels_decken_alle_kartentags_ab`, `test_route_braucht_token`.
- [ ] **Step 2:** → FAIL. **Step 3:** implementieren. **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: Karten-Route mit Ideenkarten`

---

### Task 10: Testkatalog, täglicher Katalog-Lauf, Deploy

**Files:**
- Create: `katalog/quellen/testprodukte.json`, `katalog/katalog.json` (erzeugt), `.github/workflows/server-tests.yml`, `.github/workflows/katalog.yml`, `tests/test_testprodukte.py`

**Interfaces:**
- Consumes: `scripts/build_katalog.py` (Task 5), `QuellProdukt`.

- [ ] **Step 1: Failing test** `tests/test_testprodukte.py`: Datei lädt als `list[QuellProdukt]`; mindestens 120 Einträge; ids eindeutig; mindestens 25 verschiedene `kategorie`-Werte; **mindestens 10 absichtliche Ramsch-Einträge** (unter 8 €, ohne Bild, Kabel, Kurzbeschreibung), die `pruefe_regeln` ablehnt; jeder Nicht-Ramsch-Eintrag hat `link` mit `https://`.
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3:** Testprodukte zusammenstellen (WebSearch/WebFetch): **echte** Produkte und Erlebnisse aus echten Shops (Etsy, mydays, Jochen Schweizer, Thalia, Manufactum, Shops für Garten/Tee/Spiele …), Preis 10–150 €, echte Produkt-URL, `bild_url` aus dem `og:image` der Seite; ein paar Einträge mit `varianten_gruppe` und `farbe` (auch `schwarz`). Grundbaustein 1: nichts erfinden — was sich nicht belegen lässt, weglassen.
- [ ] **Step 4:** `pytest -q` → PASS.
- [ ] **Step 5:** Katalog lokal bauen: `GROQ_API_KEY=… python scripts/build_katalog.py` → Bericht zeigt `regel_raus >= 10`, `katalog >= 80`. Stichprobe von 10 Produkten von Hand ansehen (Themen plausibel, Noten plausibel). Ergebnis committen.
- [ ] **Step 6:** `server-tests.yml` (push auf `app/**`/`main`, Pfade `app/**`, `tests/**`, `scripts/**`, `pytest -q`). `katalog.yml`: `schedule: cron "0 3 * * *"` + `workflow_dispatch`, führt Build mit Secret `GROQ_API_KEY` aus, committet `katalog/katalog.json` nur bei Änderung (`git diff --quiet || git commit`), Bot-Name `katalog-bot`.
- [ ] **Step 7: Commit** `feat: Testkatalog und täglicher Katalog-Lauf`
- [ ] **Step 8 (mit Luka):** Render-Dienst aus `render.yaml` anlegen, `APP_TOKEN` (zufällig, 32 Zeichen) und `GROQ_API_KEY` im Dashboard eintragen; GitHub-Secrets `GROQ_API_KEY`, `APP_TOKEN`. Prüfen: `curl https://geschenke.onrender.com/health` → `{"ok":true}`; ein `/karten`-Aufruf mit Token und Beispielprofil liefert Karten mit Links.

---

### Task 11: `GeschenkeCore` — Modelle, Lernen, Speicher

**Files:**
- Create: `ios/GeschenkeCore/Package.swift`, `ios/GeschenkeCore/Sources/GeschenkeCore/Modelle.swift`, `.../Gewichtung.swift`, `.../AppDaten.swift`, `ios/GeschenkeCore/Tests/GeschenkeCoreTests/ModelleTests.swift`, `.../GewichtungTests.swift`, `.../AppDatenTests.swift`, `.github/workflows/ios-core-tests.yml`

**Interfaces:**
- Produces:
  - `Package.swift` wie Wecker (`swiftLanguageModes: [.v5]`, Plattformen iOS 17 / macOS 14).
  - Codable-Spiegel der Server-Modelle mit expliziten `CodingKeys`: `Karte`, `Wunsch`, `Ausschluss`, `Profil`, `ChatNachricht`, `ChatAntwort`, `KartenAntwort` (Felder exakt wie Task 2).
  - `struct Gewichtung: Codable, Equatable { private(set) var gewichte: [String: Double]; let start: [String: Double]; private(set) var verlauf: [Bool] }` mit `init(profil: Profil)`, `mutating func ja(tags: [String])`, `mutating func nein(tags: [String])`, `mutating func setze(_ tag: String, auf wert: Double)`, `mutating func zuruecksetzen()`, `private(set) var labels: [String: String]`, `mutating func merkeLabels(_ l: [String: String])` (aus `KartenAntwort.tag_labels`), `func angewendet(auf profil: Profil) -> Profil` (ersetzt Wunsch-Gewichte, ergänzt gelernte Tags als Wünsche mit Label aus `labels`, sonst der Tag selbst).
  - `struct AppDaten: Codable { var profile: [GespeichertesProfil]; var merkliste: [MerkEintrag] }`, `struct GespeichertesProfil: Codable, Identifiable { let id: UUID; var name: String; var profil: Profil; var gewichtung: Gewichtung }`, `struct MerkEintrag: Codable, Identifiable { let id: UUID; let karte: Karte; let fuer: String; let datum: Date }`, `final class AppDatenSpeicher { init(datei: URL); func laden() -> AppDaten; func speichern(_ d: AppDaten) throws }` (fehlende/kaputte Datei → leere Daten).

Lern-Regel (Spec: Ja stärker als Nein, bei viel Nein zählen Ja deutlich mehr):

```text
JA = 0.15, NEIN = 0.05, NEU = 0.3, Bereich 0.0–2.0
neinAnteil = Anteil Nein in den letzten 20 Einträgen von verlauf (vor dieser Entscheidung),
             nur wenn verlauf.count >= 5, sonst 0
ja(tags):   für jeden Tag: vorhanden → += JA * (1 + 2 * neinAnteil); fehlt → = NEU
nein(tags): für jeden vorhandenen Tag: -= NEIN (fehlende Tags bleiben fehlend)
danach klemmen, verlauf.append(true/false)
zuruecksetzen(): gewichte = start, verlauf = []
```

- [ ] **Step 1: Failing tests:** `testKarteDekodiertSnakeCase` (JSON mit `bild_url`, `preis_von`), `testJaErhoehtUmJaSchritt`, `testNeinSenktSchwaecherAlsJaErhoeht`, `testJaNachVielNeinZaehltMehr` (19× Nein, dann Ja: Zuwachs ≈ 0.15 × (1 + 2 × 0.95)), `testUnbekannterTagWirdBeiJaGelernt`, `testGewichteBleibenImBereich`, `testSetzeUeberschreibt`, `testZuruecksetzenStelltStartHer`, `testAngewendetErsetztGewichte`, `testSpeicherRundreise`, `testKaputteDateiGibtLeereDaten`.
- [ ] **Step 2:** `swift test --package-path ios/GeschenkeCore` (CI, Container `swift:6.2`) → FAIL.
- [ ] **Step 3:** implementieren; Workflow `ios-core-tests.yml` wie Wecker. **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: GeschenkeCore mit Lernen und Speicher`

---

### Task 12: `GeschenkeCore` — API-Client

**Files:**
- Create: `ios/GeschenkeCore/Sources/GeschenkeCore/GeschenkeAPI.swift`, `ios/GeschenkeCore/Tests/GeschenkeCoreTests/GeschenkeAPITests.swift`

**Interfaces:**
- Produces: `protocol Transport { func senden(_ anfrage: URLRequest) async throws -> (Data, Int) }`; `enum APIFehler: Error, Equatable { case nichtErreichbar, kiUeberlastet, server(Int), unlesbar }`; `struct GeschenkeAPI { init(basis: URL, token: String, transport: Transport); func naechsteFrage(laenge: String, nachrichten: [ChatNachricht]) async throws -> ChatAntwort; func profilAusGespraech(_ n: [ChatNachricht]) async throws -> Profil; func profilAendern(_ p: Profil, anweisung: String) async throws -> Profil; func karten(profil: Profil, gesehen: [String], anzahl: Int) async throws -> KartenAntwort }`. Jede Anfrage: `POST`, JSON, Header `Authorization: Bearer <token>`, `timeoutInterval = 90` (Render-Kaltstart).

- [ ] **Step 1: Failing tests** mit `FakeTransport`: `testSetztBearerUndPfad`, `testKartenAnfrageKodiertSnakeCase`, `testTransportFehlerWirdNichtErreichbar` (Review Focus 4), `testStatus503WirdKiUeberlastet`, `testStatus500WirdServerFehler`, `testUnlesbaresJSONWirdUnlesbar`, `testTimeoutIst90Sekunden`.
- [ ] **Step 2:** → FAIL. **Step 3:** implementieren. **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat: API-Client im Kern`

---

### Task 13: App — Gerüst, Look, Start, Längenwahl, Gespräch, Profil speichern

**Files:**
- Create: `ios/project.yml`, `ios/Geschenke/Info.plist`, `ios/Geschenke/GeschenkeApp.swift`, `.../Look.swift`, `.../Konfiguration.swift`, `.../URLSessionTransport.swift`, `.../AppZustand.swift`, `.../StartView.swift`, `.../LaengeView.swift`, `.../ChatView.swift`, `.../ChatModell.swift`, `.../ProfilSpeichernView.swift`, `.github/workflows/ios-build.yml`

**Interfaces:**
- Consumes: `GeschenkeAPI`, `AppDatenSpeicher`, Modelle (Task 11/12).
- Produces: `Look` (Farben aus Global Constraints als `Color`, Gold-Knopfstil, Karten-Hintergrund), `Konfiguration.serverURL` (`https://geschenke.onrender.com`) und `Konfiguration.token` (aus Info.plist-Schlüssel `AppToken` = `$(APP_TOKEN)`), `final class AppZustand: ObservableObject` (hält `AppDaten`, speichert bei jeder Änderung in `Documents/appdaten.json`), `ChatModell` (Nachrichtenliste, aktueller Platzhalter, `senden(_:)`, `fertig`, `profil`).
- Verhalten: Start zeigt „Neue Suche“ (Gold) und die Liste gespeicherter Profile. Längenwahl: drei Knöpfe Schnell / Normal / Gründlich mit Untertitel „ca. 3 / 5 / 8 Fragen“. Chat: Blasen (App links dunkel, Nutzer rechts Gold), Eingabefeld zeigt den Platzhalter des Servers grau (SwiftUI-`prompt`, verschwindet beim Tippen von selbst), Senden-Knopf gesperrt bei leerem Feld. Während der Server rechnet: Tippanzeige; nach 5 s zusätzlich „Server wacht auf …“; Fehler `nichtErreichbar` → Hinweis + „Nochmal“. Bei `fertig`: Profil holen, dann Blatt „Als Profil speichern?“ mit Namensfeld und „Nicht speichern“ → weiter zum Wischen (Task 14).
- `ios-build.yml` wie Wecker, Projekt/Schema `Geschenke`, zusätzlich `APP_TOKEN="${{ secrets.APP_TOKEN }}"` als Build-Einstellung.

- [ ] **Step 1:** Dateien anlegen; Logik bleibt im Kern, die Views nur dünn.
- [ ] **Step 2:** Push → `ios-build.yml` läuft grün, Artefakt `Geschenke-ipa` existiert (`gh run view --log-failed` bei Fehlern).
- [ ] **Step 3: Commit** `feat: App-Gerüst mit Gespräch`

---

### Task 14: App — Wischen, „Was ich gelernt habe“, Merkliste, Profile

**Files:**
- Create: `ios/Geschenke/WischView.swift`, `.../KartenStapelModell.swift`, `.../KartenView.swift`, `.../GelerntView.swift`, `.../MerklisteView.swift`, `.../ProfilView.swift`

**Interfaces:**
- Consumes: `Gewichtung`, `GeschenkeAPI.karten`, `GeschenkeAPI.profilAendern`, `AppZustand`.
- Produces / Verhalten:
  - `KartenStapelModell`: hält `profil`, `gewichtung`, `gesehen`, Stapel; lädt nach, sobald ≤ 3 Karten übrig (`anzahl: 10`, Profil = `gewichtung.angewendet(auf:)`); `ja(_:)` → Merkliste + `gewichtung.ja(tags:)`; `nein(_:)` → `gewichtung.nein(tags:)`; bei gespeichertem Profil wird die Gewichtung im Profil mitgespeichert. `wird_duenn` → Hinweis „Für <Name> wird's langsam dünn“ (ohne Namen: „für diese Person“).
  - `KartenView`: Bild (`AsyncImage`) bzw. großes Emoji bei Ideenkarten, Gold-Abzeichen „Idee“, Titel, Preis („34,90 €“ bzw. „ca. 20–30 €“), Shop, Schlagwort-Abzeichen in Gold.
  - Wischen per Ziehgeste (Schwelle 100 pt) und Knöpfe ✕ / ♥.
  - Symbol oben rechts → `GelerntView`: je Wunsch ein `Slider` 0…2 mit Label und Stufe („schwach“/„normal“/„stark“), darunter „Nie zeigen:“ mit den Ausschluss-Labels, unten „Alles zurücksetzen“. Änderungen wirken auf die nächste Nachladung.
  - `MerklisteView`: Einträge gruppiert nach `fuer`, Tippen öffnet `karte.link` in Safari, Wischen löscht.
  - `ProfilView`: Name, Zusammenfassung, „Wischen“-Knopf, darunter Chat „Was hat sich geändert?“ → `profilAendern`, Ergebnis ersetzt Profil; Gewichtung startet für neue Wünsche mit deren Gewicht, bestehende gelernte Werte bleiben.
- [ ] **Step 1:** Implementieren.
- [ ] **Step 2:** CI-Build grün.
- [ ] **Step 3: Commit** `feat: Wischen, Gewichtung, Merkliste, Profile`

---

### Task 15: Abnahme am iPhone (mit Luka)

- [ ] **Step 1:** `.ipa` per `gh run download` holen, über SideStore installieren (Ablauf: Vault-Notiz `Wissen/iphone-apps-ohne-mac`).
- [ ] **Step 2: Prüfliste** (Luka am iPhone):
  1. Schnell-Gespräch für „Oma, Garten, Krimis, nichts in Schwarz, bis 50 €“ → höchstens 3 Fragen, letzte ist die Schlussfrage.
  2. Gründlich mit langen Antworten → spürbar mehr Nachfragen.
  3. 30 Karten wischen: keine schwarze Karte, nichts über 50 €, fast alles Garten/Krimi.
  4. Nur Garten-Karten nach rechts → „Was ich gelernt habe“ zeigt Garten stärker; Regler ändern wirkt; „Alles zurücksetzen“ wirkt.
  5. Profil speichern, App schließen, wieder öffnen → Profil und Merkliste da; per Chat „sie hat jetzt einen Hund“ → Wunsch „Hund“ erscheint.
  6. Ohne Netz → verständlicher Hinweis und „Nochmal“.
- [ ] **Step 3:** Befunde in den Vault (`obsidian-uebergabe`), Merge `app/v1` → `main` nur nach Lukas Okay.
