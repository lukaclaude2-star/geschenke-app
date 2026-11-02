# Geschenke-App Runde 2 – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lukas 11 Wünsche aus Runde 2 umsetzen: Designs, Sammelsuche, einheitliche Bilder, Merkliste beim Wischen, Budget-Regler, Gesehenes merken, Rückgängig, v1-Kleinpunkte, Update per Fingertipp.

**Architecture:** Server-Logik (FastAPI) bekommt Budget-Untergrenze, einen Sammel-Endpunkt und eine SideStore-Quelle; alles Testbare der App liegt im Swift-Paket `GeschenkeCore` (Linux-CI), die SwiftUI-App wird nur gebaut. Designs sind Daten (Paletten in Core, mit Kontrast-Test), die App liest sie über `Look`.

**Tech Stack:** Python 3.12/3.14, FastAPI, httpx, pytest + respx; Swift 6.2 (Swift-5-Modus), SwiftUI iOS 26, XcodeGen; GitHub Actions; Render Free; SideStore.

**Spec:** `docs/superpowers/specs/2026-11-02-geschenke-app-runde2-design.md` (baut auf `2026-11-02-geschenke-app-design.md` auf). Grundbausteine in `CLAUDE.md` gelten für jede Aufgabe.

## Global Constraints

- Branch `app/runde2`; Merge nach `main` nur mit Lukas Okay.
- Server-Tests: `.venv/Scripts/python -m pytest -q` (alle grün, aktuell 123).
- Core-Tests laufen nur in GitHub CI (`ios-core-tests`, Container swift:6.2); kein Docker lokal → nach dem Push `gh run watch`.
- App-Build: Workflow `ios-build` (macOS-Minuten zählen zehnfach → nur am Ende jeder App-Aufgabe pushen, nicht pro Schritt).
- Ausschlüsse werden nur auf dem Server geprüft (Grundbaustein 3), auch in der Sammelsuche.
- Geheimnisse (`GITHUB_TOKEN`, `DOWNLOAD_GEHEIMNIS`) nur als Render-Umgebungsvariablen, nie im Repo (Grundbaustein 9).
- Alte `appdaten.json` (v1) muss ohne Datenverlust weiter lesbar sein: jedes neue Feld wird mit `decodeIfPresent` + Standardwert gelesen.
- JSON-Schlüssel snake_case über explizite `CodingKeys` (keine keyDecodingStrategy).
- Texte in der App: Deutsch mit echten Umlauten.
- Budget-Skala: 5–500 €, bis 100 in 5er-Schritten, darüber 25er-Schritte; Griff „bis“ auf 500 = keine Obergrenze; Griff „von“ auf 5 = keine Untergrenze.
- Budget-Blase im Chat: exakt `Budget: 20–50 €`, `Budget: ab 20 €`, `Budget: bis 50 €`, `Budget: egal` (Gedankenstrich –).
- Rückgängig: höchstens 10 Schritte.

## Review Focus

1. **Altes Handy-Datenformat** (v1-`appdaten.json` ohne `gesehen`, ohne `budget_min`, ohne Design) → muss laden, nicht in `appdaten.kaputt-*.json` wandern. Test in Task 5.
2. **Sammelsuche mit überlappenden Ausschlüssen** (Mama schließt Alkohol aus, Papa nicht; Wein passt beiden) → Wein nur „für Papa“, nie „für Mama“. Test in Task 2.
3. **Rückgängig nach Ja in der Sammelsuche** → Merk-Eintrag der richtigen Person weg, Gewichtung der richtigen Person zurück, ID aus deren Gesehen-Liste raus. Test in Task 6.
4. **Falsches Download-Geheimnis / fehlende Konfiguration** → 404, kein Hinweis, dass es den Pfad gibt; kein 500. Test in Task 4.
5. **Budget-Untergrenze bei Ideenkarten** (Spanne 10–30 €, Budget ab 40 €) → Karte fällt raus; Spanne 30–60 € bei Budget 40–50 € bleibt (Überschneidung). Test in Task 1.

---

### Task 1: Budget-Spanne auf dem Server

**Files:**
- Modify: `app/modelle.py` (Profil), `app/ranking.py` (`waehle_karten`), `app/ideen.py` (Budgetprüfung + Anfrage), `app/profil.py` (Prompt + `wende_aenderung_an` + `_profil`), `app/gespraech.py` (SYSTEM)
- Test: `tests/test_budget.py`

**Interfaces:**
- Produces: `Profil.budget_min: float | None = None`; Hilfsfunktion `app/ranking.py: im_budget(preis: float, profil: Profil) -> bool`; `app/ideen.py: spanne_im_budget(von: float | None, bis: float | None, profil: Profil) -> bool`.

- [ ] **Step 1: Failing tests** in `tests/test_budget.py`:

```python
def test_budget_min_ist_hart(katalog_mit_preisen):  # Produkte zu 10, 30, 60 €
    profil = Profil(zusammenfassung="x", wuensche=[Wunsch(tag="garten", label="Garten", gewicht=1.5)],
                    ausschluesse=[], budget_min=20, budget_max=50)
    produkte, _ = waehle_karten(katalog_mit_preisen, profil, set(), 10)
    assert [p.preis for p in produkte] == [30]

def test_altes_profil_ohne_budget_min():
    assert Profil.model_validate({"zusammenfassung": "x", "wuensche": [], "ausschluesse": [],
                                  "budget_max": 50}).budget_min is None

def test_spanne_im_budget():
    p = Profil(zusammenfassung="x", wuensche=[], ausschluesse=[], budget_min=40, budget_max=50)
    assert spanne_im_budget(10, 30, p) is False
    assert spanne_im_budget(30, 60, p) is True
    assert spanne_im_budget(None, None, p) is False
    assert spanne_im_budget(None, None, Profil(zusammenfassung="x", wuensche=[], ausschluesse=[])) is True

def test_aenderung_setzt_budget_min():
    p = Profil(zusammenfassung="x", wuensche=[], ausschluesse=[], budget_min=None, budget_max=50)
    neu = wende_aenderung_an(p, {"budget_min": 20})
    assert (neu.budget_min, neu.budget_max) == (20, 50)
    assert wende_aenderung_an(neu, {}).budget_min == 20

def test_gespraech_fragt_nicht_nach_budget():
    assert "Wenn das Budget noch fehlt" not in SYSTEM
```

- [ ] **Step 2: Run** `.venv/Scripts/python -m pytest tests/test_budget.py -q` → Expected: FAIL (`budget_min` unbekannt / Import fehlt).
- [ ] **Step 3: Implement.** `im_budget`: unter `budget_min` oder über `budget_max` → False. `spanne_im_budget`: ohne Budget True; mit Budget und ohne Spanne False; sonst Überschneidung `von ≤ max` und `bis ≥ min` (fehlendes von/bis = das andere). `ideen_karten` nutzt `spanne_im_budget` statt der alten Zeile und schickt `budget_min` mit. `profil.py`: beide Prompts kennen `budget_min` (Untergrenze, null = keine); `wende_aenderung_an` übernimmt `budget_min` nur wenn der Schlüssel da ist (wie `budget_max`). `gespraech.SYSTEM`: Zeile „Wenn das Budget noch fehlt, frag danach.“ ersetzen durch „Nach dem Budget fragst du nie – das fragt die App selbst per Regler.“; „Budget“ aus der Ziel-Aufzählung streichen.
- [ ] **Step 4: Run** ganze Suite → Expected: alles grün.
- [ ] **Step 5: Commit** `feat(server): Budget-Untergrenze, KI fragt nicht mehr nach Budget`

### Task 2: Sammelsuche-Endpunkt

**Files:**
- Modify: `app/ranking.py` (Kandidaten herauslösen), `app/modelle.py`, `app/karten.py`, `app/main.py`
- Test: `tests/test_sammel.py`

**Interfaces:**
- Consumes: `waehle_karten`, `ideen_karten`, `produkt_zu_karte`, `im_budget` (Task 1).
- Produces:
  - `ranking.kandidaten(katalog, profil, gesehen) -> list[tuple[float, KatalogProdukt]]` (alle zeigbaren, Score > 0, absteigend; `waehle_karten` nutzt sie intern, Verhalten unverändert).
  - Modelle: `SammelPerson(id: str, profil: Profil, gesehen: list[str] = [])`, `KartenSammelAnfrage(personen: list[SammelPerson] (min 2, max 12), anzahl: int = Field(12, ge=2, le=30))`, `SammelKarte(fuer: str, karte: Karte)`, `KartenSammelAntwort(karten: list[SammelKarte], duenn_fuer: list[str], tag_labels: dict[str, str])`.
  - `karten.sammel_karten_fuer(katalog, anfrage) -> KartenSammelAntwort`; Route `POST /karten/sammel` (geschützt).

Algorithmus (vom Test nicht vollständig bestimmt):
1. Pro Person `kandidaten(...)` – damit gelten Ausschlüsse/Budget/Gesehen pro Person.
2. Jede Produkt-ID gehört der Person mit dem höchsten Score (Gleichstand: Reihenfolge in `personen`).
3. Anteil pro Person = `ceil(anzahl / len(personen))`; pro Person die besten eigenen Produkte mit der Abwechslungs-Logik (`_gierig`) bis zum Anteil.
4. Fehlen einer Person Karten (weniger als Anteil gute, Score ≥ GUT_AB), → ihre ID in `duenn_fuer` und `ideen_karten(profil, fehlend, gesehen)` für sie.
5. Reißverschluss: abwechselnd eine Karte je Person, bis `anzahl` erreicht; Karten ohne Link fallen raus.

- [ ] **Step 1: Failing tests** in `tests/test_sammel.py` (Ideenkarten per `monkeypatch` auf `[]`):

```python
async def test_ausschluss_gilt_nur_fuer_die_person(katalog):  # enthält "Rotwein-Tasting" (eigenschaft alkohol, thema wein)
    mama = SammelPerson(id="mama", profil=profil(wuensche={"wein": 1.5}, ausschluesse=["eigenschaft:alkohol"]))
    papa = SammelPerson(id="papa", profil=profil(wuensche={"wein": 1.0}))
    antwort = await sammel_karten_fuer(katalog, KartenSammelAnfrage(personen=[mama, papa], anzahl=10))
    wein = [k for k in antwort.karten if "wein" in k.karte.tags]
    assert wein and all(k.fuer == "papa" for k in wein)

async def test_karte_erscheint_nur_einmal_bei_bester_person(katalog): ...
    # Gartenprodukt: mama garten 1.5, papa garten 0.5 → genau einmal, fuer == "mama"

async def test_reissverschluss(katalog): ...
    # erste vier Karten: fuer == ["mama","papa","mama","papa"]

async def test_gesehen_pro_person(katalog): ...
    # ID in mama.gesehen → taucht nicht für mama auf, darf aber für papa kommen

async def test_route_braucht_token_und_zwei_personen(client): ...
    # ohne Token 401; mit einer Person 422
```

- [ ] **Step 2: Run** `pytest tests/test_sammel.py -q` → Expected: FAIL (ImportError).
- [ ] **Step 3: Implement** wie oben.
- [ ] **Step 4: Run** ganze Suite → grün.
- [ ] **Step 5: Commit** `feat(server): Sammelsuche für mehrere Profile`

### Task 3: Server-Kleinpunkte (M5, M11)

**Files:** Modify `app/ki.py`, `app/modelle.py` (QuellProdukt); Test `tests/test_review_fixes.py`

**Interfaces:** Produces `app/ki.py: GESAMT_ZEITLIMIT = 45.0`; `app/modelle.py: ohne_html(text: str) -> str`.

- [ ] **Step 1: Failing tests:**

```python
async def test_frage_json_gibt_nach_gesamtzeit_auf(monkeypatch):
    monkeypatch.setattr(ki, "GESAMT_ZEITLIMIT", 0.05)
    # respx: jedes Modell antwortet erst nach 0.2 s (side_effect mit asyncio.sleep)
    with pytest.raises(KiUeberlastet):
        await frage_json("s", "n")

def test_beschreibung_ohne_html():
    p = QuellProdukt(id="a", titel="t", beschreibung="<p>Schöner&nbsp;Kurs<br/>mit &amp; ohne</p>",
                     preis=20, bild_url=None, link="x", shop="s")
    assert p.beschreibung == "Schöner Kurs mit & ohne"
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** `frage_json`: ganze Modellkette in `asyncio.timeout(GESAMT_ZEITLIMIT)`, `TimeoutError` → `KiUeberlastet`. `ohne_html`: Tags durch Leerzeichen ersetzen, `html.unescape`, Leerraum zusammenfassen, strip; als `field_validator("beschreibung", mode="before")` an `QuellProdukt` (erbt auf `KatalogProdukt`).
- [ ] **Step 4: Run** ganze Suite → grün. Zusätzlich `python -c "from app.katalog.laden import lade_alle; ..."` → Katalog lädt, keine `<` mehr in Beschreibungen.
- [ ] **Step 5: Commit** `fix(server): Gesamt-Zeitlimit für KI, HTML aus Beschreibungen`

### Task 4: SideStore-Quelle auf dem Server

**Files:**
- Create: `app/download.py`
- Modify: `app/config.py`, `app/main.py`, `render.yaml`
- Test: `tests/test_download.py`

**Interfaces:**
- Produces: Settings `github_token: str = ""`, `download_geheimnis: str = ""`, `github_repo: str = "lukaclaude2-star/geschenke-app"`, `oeffentliche_url: str = "https://geschenke.onrender.com"`; Routen `GET /dl/{geheimnis}/source.json`, `GET /dl/{geheimnis}/Geschenke.ipa`; Release-Konvention: Tag `app-<N>`, Asset `Geschenke.ipa`, App-Version `1.0.<N>`.

`source.json` (AltStore/SideStore-Format):
```json
{"name": "Geschenke (Luka)", "identifier": "de.luka.geschenke.quelle",
 "apps": [{"name": "Geschenke", "bundleIdentifier": "de.luka.geschenke", "developerName": "Luka",
   "localizedDescription": "Geschenke per Chat und Wischen finden.", "iconURL": "",
   "versions": [{"version": "1.0.<N>", "buildVersion": "<N>", "date": "<published_at>",
     "downloadURL": "<oeffentliche_url>/dl/<geheimnis>/Geschenke.ipa", "size": <asset.size>}]}],
 "news": []}
```

- [ ] **Step 1: Failing tests** (respx auf `https://api.github.com/repos/<repo>/releases/latest`):

```python
def test_falsches_geheimnis_404(client_mit_geheimnis): assert client.get("/dl/falsch/source.json").status_code == 404
def test_ohne_konfiguration_404(client_ohne_geheimnis): assert client.get("/dl//source.json").status_code == 404 and client.get("/dl/x/source.json").status_code == 404
def test_source_json_aus_release(...):  # Release tag app-42, Asset size 1234
    daten = client.get("/dl/geheim/source.json").json()
    v = daten["apps"][0]["versions"][0]
    assert (v["version"], v["buildVersion"], v["size"]) == ("1.0.42", "42", 1234)
    assert v["downloadURL"].endswith("/dl/geheim/Geschenke.ipa")
def test_ipa_wird_durchgereicht(...):  # Asset-URL liefert b"IPA"
    r = client.get("/dl/geheim/Geschenke.ipa"); assert r.status_code == 200 and r.content == b"IPA"
def test_github_nicht_erreichbar_503(...): ...
def test_token_geht_nur_an_github(...):  # Authorization-Header nur bei api.github.com, nicht beim Redirect-Ziel
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Geheimnis-Vergleich mit `hmac.compare_digest`; leeres Geheimnis = immer 404. GitHub-API mit `Authorization: Bearer <github_token>`, `Accept: application/vnd.github+json`; IPA über `GET /repos/<repo>/releases/assets/<id>` mit `Accept: application/octet-stream`, Redirect manuell folgen **ohne** Authorization-Header, Antwort als `StreamingResponse` (`application/octet-stream`). Fehler bei GitHub → 503. `render.yaml`: `GITHUB_TOKEN` und `DOWNLOAD_GEHEIMNIS` mit `sync: false`.
- [ ] **Step 4: Run** ganze Suite → grün.
- [ ] **Step 5: Commit** `feat(server): SideStore-Quelle für Update per Fingertipp`

### Task 5: Core – Modelle, API, Budget-Skala

**Files:**
- Modify: `ios/GeschenkeCore/Sources/GeschenkeCore/Modelle.swift`, `AppDaten.swift`, `GeschenkeAPI.swift`
- Create: `ios/GeschenkeCore/Sources/GeschenkeCore/BudgetSkala.swift`
- Test: `ModelleTests.swift`, `AppDatenTests.swift`, `GeschenkeAPITests.swift`, new `BudgetSkalaTests.swift`

**Interfaces:**
- Produces:
  - `Profil.budgetMin: Double?` (Schlüssel `budget_min`, immer mitgeschickt; Decoding `decodeIfPresent`); Init bekommt `budgetMin: Double? = nil` als letzten Parameter.
  - `GespeichertesProfil.gesehen: [String]` (Standard `[]`, `decodeIfPresent`).
  - `AppDaten.design: String` (Standard `"nachtblau"`, `decodeIfPresent`).
  - `SammelPerson(id: String, profil: Profil, gesehen: [String])`, `SammelKarte(fuer: String, karte: Karte)`, `KartenSammelAntwort(karten: [SammelKarte], duennFuer: [String], tagLabels: [String: String])`.
  - `GeschenkeAPI.sammelKarten(personen: [SammelPerson], anzahl: Int) async throws -> KartenSammelAntwort` → `POST karten/sammel`.
  - `enum BudgetSkala { static let stufen: [Double]; static func grenzen(von: Double, bis: Double) -> (min: Double?, max: Double?); static func text(von: Double?, bis: Double?) -> String }` – `text` bekommt die Grenzen aus `grenzen`.

- [ ] **Step 1: Failing tests:**

```swift
func testV1DatenLadenOhneVerlust() throws {
    // JSON exakt im v1-Format: Profil ohne budget_min, GespeichertesProfil ohne gesehen, AppDaten ohne design
    let daten = try JSONDecoder().decode(AppDaten.self, from: v1JSON)
    XCTAssertEqual(daten.profile.first?.gesehen, [])
    XCTAssertNil(daten.profile.first?.profil.budgetMin)
    XCTAssertEqual(daten.design, "nachtblau")
}
func testSpeicherLaedtV1DateiOhneKaputtKopie() throws { /* Datei mit v1JSON → laden → speichern → keine appdaten.kaputt-*.json im Ordner */ }
func testProfilSchicktBudgetMinImmer() { /* encode mit nil → JSON enthält "budget_min":null */ }
func testSammelKartenSchicktPersonenUndLiestFuer() async throws { /* Fake-Transport: Pfad endet auf karten/sammel, Body hat personen[0].id, Antwort mit "fuer":"mama","duenn_fuer":[] */ }
func testBudgetStufen() {
    XCTAssertEqual(BudgetSkala.stufen.first, 5); XCTAssertEqual(BudgetSkala.stufen.last, 500)
    XCTAssertTrue(BudgetSkala.stufen.contains(95)); XCTAssertTrue(BudgetSkala.stufen.contains(125))
    XCTAssertFalse(BudgetSkala.stufen.contains(105))
}
func testBudgetGrenzenUndText() {
    XCTAssertTrue(BudgetSkala.grenzen(von: 5, bis: 500) == (nil, nil))
    XCTAssertEqual(BudgetSkala.text(von: 20, bis: 50), "Budget: 20–50 €")
    XCTAssertEqual(BudgetSkala.text(von: 20, bis: nil), "Budget: ab 20 €")
    XCTAssertEqual(BudgetSkala.text(von: nil, bis: 50), "Budget: bis 50 €")
    XCTAssertEqual(BudgetSkala.text(von: nil, bis: nil), "Budget: egal")
}
```

- [ ] **Step 2: Push, CI** `gh run watch` (ios-core-tests) → Expected: FAIL (Kompilierfehler).
- [ ] **Step 3: Implement.** Eigene `init(from:)` für `GespeichertesProfil` und `AppDaten`; App-Code an neue Init-Signaturen anpassen, damit `ios-build` später kompiliert.
- [ ] **Step 4: Push, CI** → grün.
- [ ] **Step 5: Commit** `feat(core): Budget-Spanne, Gesehen-Liste, Sammel-API, abwärtskompatibel`

### Task 6: Core – Rückgängig-Verlauf und Gewichtungs-Fixes (M10)

**Files:**
- Create: `ios/GeschenkeCore/Sources/GeschenkeCore/WischVerlauf.swift`
- Modify: `Gewichtung.swift`
- Test: new `WischVerlaufTests.swift`, `GewichtungTests.swift`

**Interfaces:**
- Produces:
  - `struct WischSchritt: Equatable { let karte: Karte; let person: Int; let ja: Bool; let gewichtungVorher: Gewichtung; let merkID: UUID? }` (`person` = Index in der Personenliste des Stapels, 0 bei Einzelsuche).
  - `struct WischVerlauf { static let maximum = 10; mutating func merke(_ schritt: WischSchritt); mutating func zurueck() -> WischSchritt?; var kannZurueck: Bool }` – ältester fällt bei mehr als 10 raus.
  - `Gewichtung.uebernimm(profil:)` übernimmt jetzt auch **geänderte** Gewichte bestehender Wünsche (wenn neues Profilgewicht ≠ altes Startgewicht → aktueller Wert = neues Gewicht).

- [ ] **Step 1: Failing tests:**

```swift
func testHoechstensZehnSchritte() { /* 12 merken → 10× zurueck liefert Schritt 12…3, dann nil */ }
func testZurueckGibtGewichtungVorher() { /* gewichtungVorher bleibt unverändert, auch wenn danach ja() lief */ }
func testUebernimmtGeaendertesGewicht() {
    var g = Gewichtung(profil: profil(["garten": 1.0])); g.ja(tags: ["garten"])
    g.uebernimm(profil: profil(["garten": 0.5]))
    XCTAssertEqual(g.gewichte["garten"], 0.5)
}
func testUebernimmBehaeltGelerntesBeiGleichemGewicht() { /* garten 1.0 → ja → uebernimm mit 1.0 → 1.15 bleibt */ }
```

- [ ] **Step 2–4:** Push, CI rot → implementieren → CI grün.
- [ ] **Step 5: Commit** `feat(core): Rückgängig-Verlauf, geänderte Wunsch-Gewichte übernehmen`

### Task 7: Core – Design-Paletten mit Kontrast-Test

**Files:**
- Create: `ios/GeschenkeCore/Sources/GeschenkeCore/Designs.swift`
- Test: new `DesignsTests.swift`

**Interfaces:**
- Produces:
  - `public enum DesignStil { case normal, deco, pinnwand }`
  - `public struct Palette { id: String; name: String; hell: Bool; stil: DesignStil; hintergrund, karte, rand, text, akzent, aufAkzent, preis: UInt32 }`
  - `public enum Designs { static let alle: [Palette]; static let standard = "nachtblau"; static func palette(_ id: String) -> Palette }` (unbekannte ID → Standard)
  - `public func kontrast(_ a: UInt32, _ b: UInt32) -> Double` (WCAG-Kontrastverhältnis)

Werte (ID · Name · hell · stil · hintergrund / karte / rand / text / akzent / aufAkzent / preis):
- `nachtblau` · Nachtblau & Gold · nein · normal · 11131C / 1C1F2B / 2C3040 / EEEEEE / E0B84C / 11131C / E0B84C
- `wald` · Waldgrün & Messing · nein · normal · 0F1A14 / 18281F / 2C4335 / EEF3EA / C9A45C / 1A1408 / D8B874
- `bordeaux` · Bordeaux & Creme · nein · normal · 1C0D11 / 2B1419 / 4A2229 / F7ECE4 / EFE0C8 / 3A1018 / EFD7B0
- `polarlicht` · Polarlicht · nein · normal · 0A1220 / 121D30 / 24365A / E8F1FF / 4FE0C0 / 04211B / A98BFF
- `graphit` · Graphit & Lime · nein · normal · 0C0C0C / 171717 / 2C2C2C / F5F5F5 / C8F53C / 121A00 / C8F53C
- `mint` · Mint & Marine · ja · normal · EEF6F3 / FFFFFF / CFE3DC / 12263A / 14375E / FFFFFF / 17735D
- `deco` · Art déco · nein · deco · 0E1A17 / 13241F / C9A45C / E9DCB8 / C9A45C / 0E1A17 / C9A45C
- `pinnwand` · Polaroid-Pinnwand · ja · pinnwand · C89A64 / FDFDF8 / E2D6C0 / 2B2118 / C0392B / FFFFFF / C0392B

(Mint-Preis ist gegenüber der Vorschau von #1F8A70 auf #17735D abgedunkelt – sonst Kontrast < 4,5.)

- [ ] **Step 1: Failing tests:**

```swift
func testAchtDesignsStandardZuerst() { XCTAssertEqual(Designs.alle.map(\.id), ["nachtblau","wald","bordeaux","polarlicht","graphit","mint","deco","pinnwand"]) }
func testUnbekanntWirdStandard() { XCTAssertEqual(Designs.palette("gibtsnicht").id, "nachtblau") }
func testKontrastBekannt() { XCTAssertEqual(kontrast(0x000000, 0xFFFFFF), 21, accuracy: 0.01) }
func testAllesLesbar() {
    for p in Designs.alle {
        XCTAssertGreaterThanOrEqual(kontrast(p.text, p.karte), 4.5, p.id)
        XCTAssertGreaterThanOrEqual(kontrast(p.text, p.hintergrund), 4.5, p.id)
        XCTAssertGreaterThanOrEqual(kontrast(p.aufAkzent, p.akzent), 4.5, p.id)
        XCTAssertGreaterThanOrEqual(kontrast(p.preis, p.karte), 4.5, p.id)
    }
}
```

- [ ] **Step 2–4:** CI rot → implementieren → CI grün. Scheitert ein Kontrast mit den Werten oben: Farbe minimal anpassen und als Ruling ledgern.
- [ ] **Step 5: Commit** `feat(core): acht Design-Paletten mit Kontrast-Test`

### Task 8: App – Designs, einheitliche Bilder, Merkliste mit Bildern

**Files:**
- Modify: `ios/Geschenke/Look.swift`, `GeschenkeApp.swift`, `StartView.swift` (Einstellungen), `KartenView.swift`, `MerklisteView.swift`, `AppZustand.swift`, `ios/project.yml` (`UIUserInterfaceStyle` entfernen)
- Create: `ios/Geschenke/KartenBild.swift`, `ios/Geschenke/DesignHintergrund.swift`

**Interfaces:**
- Consumes: `Designs`, `Palette`, `AppDaten.design` (Task 5, 7).
- Produces: `Look.akzent` (ersetzt `Look.gold` überall), `Look.aufAkzent`, `Look.preis`, `Look.palette`; `AppZustand.setzeDesign(_ id: String)`; `KartenBild(karte: Karte)` – 4:3, `scaledToFill().clipped()`, Ecken 12; ohne Bild/Ladefehler: Kachel in `Look.karte`/`Look.akzent` mit `karte.titel` (Idee: Suchbegriff/Titel) statt Emoji.

- [ ] **Step 1:** `Look` liest `Designs.palette(aktuelleID)` (statisch gesetzt von `AppZustand`); Wurzel-View bekommt `.id(zustand.daten.design)` und `.preferredColorScheme(palette.hell ? .light : .dark)`, damit alles neu zeichnet.
- [ ] **Step 2:** Einstellungen (bestehende `EinstellungenView`): Abschnitt „Design“ mit Liste aller 8, je Zeile drei Farbpunkte + Name + Haken.
- [ ] **Step 3:** `stil == .deco`: Schrift `.serif`, Kartenrahmen doppelt in Akzent (Rand + Innenrand 4 pt Abstand), Knöpfe als Raute, Hintergrund mit feinem Rautenmuster (`DesignHintergrund`). `stil == .pinnwand`: Handschrift `Noteworthy` für Titel/„für …“, Karte 2° gedreht mit Klebestreifen oben und Schatten, Korkhintergrund mit Punktmuster. Verbindliche Optik: `docs/superpowers/specs/runde2-vorschau/designs-wild.html`.
- [ ] **Step 4:** `KartenView` und `MerklisteView` nutzen `KartenBild`; Preise: Produkt `preisText` ohne „ca.“ (prüfen), Idee Spanne.
- [ ] **Step 5:** Push → `gh workflow run ios-build -f runner=macos-15 --ref app/runde2` → Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 6: Commit** `feat(app): wählbare Designs, einheitliche Bilder, Merkliste mit Bildern`

### Task 9: App – Wischen: Merkliste-Knopf, Rückgängig, Gesehenes, Mehrpersonen-Stapel

**Files:** Modify `KartenStapelModell.swift`, `WischView.swift`, `ChatView.swift` (WischZiel), `ProfilView.swift`, `GelerntView.swift`, `AppZustand.swift`

**Interfaces:**
- Consumes: `WischVerlauf`, `WischSchritt`, `GespeichertesProfil.gesehen`, `GeschenkeAPI.sammelKarten`, `SammelPerson` (Tasks 5, 6).
- Produces:
  - `struct WischPerson { name: String?; profil: Profil; profilID: UUID?; gewichtung: Gewichtung; gesehen: [String] }`; `WischZiel` hält `personen: [WischPerson]` (1 = Einzelsuche, ≥ 2 = Sammelsuche).
  - `KartenStapelModell`: Stapel aus `StapelKarte(karte: Karte, person: Int)`; `ja(_:)`, `nein(_:)`, `zurueck()`, `kannZurueck`; pro Person eigene `Gewichtung` und `gesehen`; Einzelsuche → `api.karten`, Sammelsuche → `api.sammelKarten` (`SammelPerson.id` = Index als String).
  - `AppZustand.merke(...) -> UUID?` (ID des neuen Eintrags), `AppZustand.sichereGelerntes(_ id: UUID, gewichtung: Gewichtung, gesehen: [String])` – liest das **aktuell gespeicherte** Profil und wendet `gewichtung.uebernimm(profil:)` darauf an, bevor gespeichert wird (M9).

- [ ] **Step 1:** Gesehen: dauerhaft nur **gewischte** IDs (`ja`/`nein` hängen an `person.gesehen` an und sichern); an den Server geht `gesehen + IDs im Stapel`. `zurueck()`: Karte vorn in den Stapel, Gewichtung der Person = `gewichtungVorher`, ID aus deren `gesehen`, bei `merkID` den Merk-Eintrag entfernen, sichern.
- [ ] **Step 2:** `WischView`: Toolbar rechts Merkliste-Knopf mit Anzahl (öffnet `MerklisteView` als Sheet, Stapel bleibt), Regler-Knopf wie bisher; unten ↶ (deaktiviert ohne Verlauf) | ✕ | ♥. Karte zeigt „für <Name>“ als Abzeichen, wenn `personen.count > 1`.
- [ ] **Step 3:** Kleinpunkte: M6 `neuSortieren` nur, wenn sich die Gewichtung seit dem Öffnen von „Gelernt“ geändert hat; M7 Leer-Text: „Mehr passende Geschenke habe ich gerade nicht. Vielleicht schränken Budget oder Ausschlüsse stark ein – ändere das im Profil oder die Gewichtung oben rechts.“; „Gelernt“ bekommt Knopf „Gesehene wieder zeigen“ (leert `gesehen` aller Personen des Stapels und lädt neu).
- [ ] **Step 4:** Einzelsuche ohne Profil (M2/M3/#8): `ChatView` hält das `KartenStapelModell` selbst (einmal erzeugt, wenn das Profil fertig ist) und übergibt es an `WischView` (`@ObservedObject`); im Chat erscheint, sobald ein Profil da ist, der Knopf „Weiter wischen“. Navigation über `navigationDestination(item:)` an genau einer Stelle, damit Sheets das Push nicht verschlucken.
- [ ] **Step 5:** Push → `ios-build` → BUILD SUCCEEDED.
- [ ] **Step 6: Commit** `feat(app): Rückgängig, Merkliste beim Wischen, Gesehenes merken, Mehrpersonen-Stapel`

### Task 10: App – Budget-Regler und Chat-Kleinpunkte

**Files:** Modify `ChatModell.swift`, `ChatView.swift`, `ProfilView.swift`; Create `ios/Geschenke/BudgetRegler.swift`

**Interfaces:**
- Consumes: `BudgetSkala` (Task 5), `Profil.budgetMin`.
- Produces: `BudgetRegler(von: Binding<Double>, bis: Binding<Double>)` (zwei Griffe auf `BudgetSkala.stufen`, Anzeige wie `BudgetSkala.text`); `ChatModell.budgetOffen: Bool`, `ChatModell.budgetGewaehlt(von: Double?, bis: Double?) async`.

- [ ] **Step 1:** Nach der ersten Nutzerantwort: `budgetOffen = true`, keine Server-Anfrage; Chat zeigt App-Blase „Wie viel möchtest du ausgeben?“ plus Regler-Karte mit „Passt“ und „Egal“. `budgetGewaehlt` hängt die Nutzer-Blase (`BudgetSkala.text`) an, merkt die Grenzen und holt die nächste Frage. Nach `profilAusGespraech` überschreibt die App `budgetMin`/`budgetMax` mit den Regler-Werten.
- [ ] **Step 2:** M4: `fertig == false` ohne Frage → App-Blase „Gibt es sonst noch etwas, das ich wissen sollte?“. M1: „Speichern und los“ sperrt sich nach dem ersten Tipp (Status `speichert`).
- [ ] **Step 3:** `ProfilView`: Budget-Zeile mit `BudgetRegler` + „Übernehmen“ (speichert direkt, ohne KI); `aendern()` liest die Gewichtung aus `zustand.profil(id)` statt aus dem alten `eintrag` (M9).
- [ ] **Step 4:** Push → `ios-build` → BUILD SUCCEEDED.
- [ ] **Step 5: Commit** `feat(app): Budget-Regler mit Spanne, Chat-Kleinpunkte`

### Task 11: App – Sammelsuche-Einstieg

**Files:** Modify `StartView.swift`; Create `ios/Geschenke/SammelAuswahlView.swift`

**Interfaces:** Consumes `WischZiel(personen:)`, `WischPerson` (Task 9).

- [ ] **Step 1:** Startbildschirm: Knopf „Für mehrere suchen“, sichtbar ab 2 gespeicherten Profilen. `SammelAuswahlView`: Liste aller Profile mit Häkchen, Knopf „Los (n)“ aktiv ab 2; baut `WischZiel` mit je Profil `WischPerson(name, profil, id, gewichtung, gesehen)`; Titel der Wisch-Ansicht „Für n Personen“.
- [ ] **Step 2:** Push → `ios-build` → BUILD SUCCEEDED.
- [ ] **Step 3: Commit** `feat(app): Sammelsuche für mehrere Profile`

### Task 12: Build-Versionen und Release für Update per Fingertipp

**Files:** Modify `.github/workflows/ios-build.yml`

**Interfaces:** Consumes Release-Konvention aus Task 4 (Tag `app-<N>`, Asset `Geschenke.ipa`, Version `1.0.<N>`).

- [ ] **Step 1:** `xcodebuild` bekommt `MARKETING_VERSION=1.0.${{ github.run_number }} CURRENT_PROJECT_VERSION=${{ github.run_number }}`; Job `permissions: contents: write`.
- [ ] **Step 2:** Neuer Schritt nur `if: github.ref == 'refs/heads/main'`: `gh release create app-${{ github.run_number }} ios/Geschenke.ipa --title "App ${{ github.run_number }}" --notes "${{ github.event.head_commit.message || 'manuell' }}"` mit `GH_TOKEN: ${{ github.token }}`.
- [ ] **Step 3:** Prüfen: Build auf `app/runde2` erstellt **kein** Release (`gh release list` leer), Version im Info.plist der IPA = `1.0.<N>` (`unzip -p … Info.plist | plutil` bzw. `python -c plistlib`).
- [ ] **Step 4: Commit** `ci: Versionsnummer und Release für SideStore-Quelle`

Nach dem Merge (mit Lukas Okay): erster `main`-Build erzeugt `app-<N>`; dann `curl https://geschenke.onrender.com/dl/<geheimnis>/source.json` prüfen und Luka den Link für SideStore → Sources → + geben.
