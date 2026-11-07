# Katalog groß – Bauplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kleidung in drei Stufen, neuer Bereich Franchises, ≈ 30.000 neue Produkte, bis 13.11.2026 alles verschlagwortet und schnell auslieferbar.

**Architecture:** Das Vokabular bleibt die einzige Quelle (`app/vokabular.py`). Neu ist eine Gruppen-Tabelle (Gruppe → Stichwörter). Ranking und Ausschluss erweitern die Produkt-Stichwörter beim Lesen um ihre Gruppe, an der Verschlagwortung ändert sich dafür nichts. Mistral kommt als zusätzlicher Arbeiter in die bestehende parallele Verschlagwortung. Neue Produkte liefert der vorhandene Sammler aus neuen Shops in `katalog/shops.json`.

**Tech Stack:** Python 3.12, FastAPI, httpx, pydantic, pytest + respx, GitHub Actions; Swift nur über die erzeugte `Bereiche.swift`.

**Spec:** `docs/superpowers/specs/2026-11-06-katalog-gross-design.md`

## Global Constraints

- Grundbausteine aus `CLAUDE.md` gelten für jeden Task. Besonders 1 (nur echte Produkte), 3 (Ausschlüsse hart), 4 (Ramsch-Filter, Note ≥ 6), 9 (Schlüssel nie im Repo), 10 (an Mistral nur Produktdaten), 11 (nur Gratis-Tarif).
- Bestehende Stichwort-Schlüssel nie umbenennen oder löschen. Profile auf dem Handy speichern sie.
- `VOKABULAR_VERSION = 4`.
- `vokabular_text()` ohne Bereichsnamen, Bereichsschlüssel oder `[`.
- Jedes Stichwort hat ein Foto in `app/static/beispielbilder/<tag>.jpg`. Bei Franchises nur neutrale Motive ohne Logo oder Figur.
- Shops: robots.txt beachten, kein Shopify, nur deutsche Seiten, keine Billig-Marktplätze, Fanartikel nur aus Shops mit Lizenzware.
- Regel-Filter (`app/katalog/regeln.py`, `min_preis` usw.) wird nicht gelockert.
- Commits nur auf `katalog-gross`. Merge nach `main` nur mit Lukas ausdrücklichem Okay.
- Swift-Quelltext nur per Edit oder Skriptdatei schreiben, nicht per Bash-Heredoc. Python unter Windows mit `newline=''` lesen und schreiben.
- Tests: `.venv/Scripts/python -m pytest -q` (Ausgangsstand 280 grün).

## Review Focus

1. **Ausschluss einer Gruppe trifft alte Produkte:** „thema:schuhe“ schließt auch ein Produkt aus, das nur `["sneaker"]` hat (alt verschlagwortet, ohne Gruppen-Tag). → Test in Task 2.
2. **Ausschluss eines Stichworts trifft nicht die ganze Gruppe:** „thema:stiefel“ lässt ein Produkt mit `["sneaker"]` durch. → Test in Task 2.
3. **Gespeicherte Profile mit umgezogenen Stichwörtern** (`harry_potter`, `schmuck`) funktionieren weiter. Der Schlüssel existiert, der Bereich ist neu. → Test in Task 1.
4. **Größenvarianten fluten den Stapel:** dasselbe Shirt in S, M, L und XL als vier Karten. → Test in Task 3.
5. **Fehlender Mistral-Schlüssel im Nachtlauf:** Ohne `MISTRAL_API_KEY` läuft der Bau wie heute, ohne Absturz. → Test in Task 4.

---

### Task 1: Vokabular – Kleidung mit Gruppen, Franchises, Fotos, App-Tabelle

**Files:**
- Modify: `app/vokabular.py`
- Modify: `tests/test_vokabular.py`
- Modify: `scripts/beispielbilder_suche.json`, neu: `app/static/beispielbilder/<tag>.jpg` je neuem Stichwort
- Modify (erzeugt): `ios/GeschenkeCore/Sources/GeschenkeCore/Bereiche.swift`

**Interfaces:**
- Produces:
  - `GRUPPEN: dict[str, tuple[str, ...]]`: Gruppen-Stichwort → Stichwörter darunter (ohne die Gruppe selbst)
  - `THEMA_GRUPPE: dict[str, str]`: Stichwort → Gruppen-Stichwort
  - `def mit_gruppen(tags) -> set[str]`: Tags plus ihre Gruppen
  - Gruppen-Stichwörter stehen selbst in `THEMEN`.

Festgelegte Inhalte:

- Bereich `mode` bleibt als Schlüssel, Label wird `"👕 Kleidung & Mode"`. Das ist der Bereich „Kleidung“ aus der Spec, so bleibt die Merkliste ohne Umzug stabil.
- Gruppen in `mode`. Neue Schlüssel *kursiv*, alle anderen gibt es schon:
  - `schuhe`: sneaker, *stiefel, sandalen, pumps, hausschuhe, laufschuhe, ballerinas, business_schuhe*
  - `jacken`: *winterjacken, lederjacken, regenjacken, jeansjacken, maentel, westen*
  - *`oberteile`*: *t_shirts, hemden, blusen, pullover, hoodies, poloshirts, strickjacken*
  - *`hosen_roecke`*: *jeans, jogginghosen, shorts, roecke*
  - *`kleider`*: *abendkleider, sommerkleider*
  - `schmuck`: *ketten, ringe, ohrringe, armbaender, charms*
  - `taschen`: rucksaecke, geldboersen, *handtaschen, umhaengetaschen, sporttaschen*
  - *`kopfbedeckungen`*: huete, *caps, beanies*
  - *`accessoires`*: uhren, sonnenbrillen, krawatten, manschettenknoepfe, schals_muetzen, socken, *guertel, handschuhe*
  - *`waesche`*: pyjamas, *bademode, bademaentel*
- Ohne Gruppe bleiben in `mode`: mode, streetwear, vintage, tracht.
- Neuer Bereich `franchises`: `"⭐ Franchises & Fanwelten"`, in `BEREICHE` direkt nach `popkultur`.
  - Aus popkultur ziehen um: harry_potter, star_wars, herr_der_ringe, disney, star_trek.
  - Aus gaming ziehen um: pokemon, minecraft.
  - lego bleibt in spiele, nintendo bleibt in gaming.
  - Neu: hello_kitty, marvel, dc_comics, minions, barbie, super_mario, zelda, peanuts, simpsons, one_piece, stranger_things, friends, paw_patrol, peppa_wutz, die_maus, sailor_moon, studio_ghibli, naruto, dragon_ball, fortnite, sonic, game_of_thrones, winnie_puuh, eiskoenigin, toy_story, jurassic_park, sesamstrasse.
  - Jedes Label beginnt mit einem Emoji und muss nach dem Emoji eindeutig sein, siehe vorhandenen Test.
- `VOKABULAR_VERSION = 4`.

- [ ] **Step 1: Failing tests in `tests/test_vokabular.py`**

```python
from app.vokabular import GRUPPEN, THEMA_GRUPPE, mit_gruppen

def test_kleidung_drei_stufen():
    assert THEMA_GRUPPE["stiefel"] == "schuhe"
    assert THEMA_GRUPPE["sneaker"] == "schuhe"
    assert THEMA_GRUPPE["t_shirts"] == "oberteile"
    assert "schuhe" in THEMEN and THEMA_BEREICH["schuhe"] == "mode"
    assert all(THEMA_BEREICH[g] == "mode" for g in GRUPPEN)
    assert all(THEMA_BEREICH[t] == THEMA_BEREICH[g] for g, ts in GRUPPEN.items() for t in ts)
    assert not set(GRUPPEN) & set(THEMA_GRUPPE)  # Gruppe ist nie selbst Kind

def test_mit_gruppen():
    assert mit_gruppen(["stiefel", "grillen"]) == {"stiefel", "schuhe", "grillen"}
    assert mit_gruppen([]) == set()

def test_franchises_und_umzug_alter_schluessel():
    assert BEREICHE["franchises"]
    for tag in ("hello_kitty", "marvel", "harry_potter", "pokemon", "star_wars"):
        assert THEMA_BEREICH[tag] == "franchises"
    assert THEMA_BEREICH["lego"] == "spiele"
    assert THEMA_BEREICH["schmuck"] == "mode"  # alter Schlüssel, jetzt Gruppe
    assert VOKABULAR_VERSION == 4
```

`test_470_stichwoerter_in_oberbereichen` auf die neuen exakten Zahlen setzen: `len(BEREICHE) == 24`, `len(THEMEN)` = die gezählte neue Zahl. `test_vokabular_text_ohne_bereichsueberschriften` bleibt unverändert.

- [ ] **Step 2: Laufen lassen und Fehlschlag sehen**

Run: `.venv/Scripts/python -m pytest tests/test_vokabular.py -q`
Expected: FAIL (ImportError `GRUPPEN`)

- [ ] **Step 3: `app/vokabular.py` umsetzen**

`THEMEN_NACH_BEREICH` bleibt flach je Bereich. `GRUPPEN` steht daneben, `THEMA_GRUPPE` wird daraus abgeleitet. `mit_gruppen(tags) = set(tags) | {THEMA_GRUPPE[t] for t in tags if t in THEMA_GRUPPE}`.

- [ ] **Step 4: Tests grün**

Run: `.venv/Scripts/python -m pytest tests/test_vokabular.py -q`
Expected: PASS

- [ ] **Step 5: Fotos holen**

Für jedes neue Stichwort einen englischen Suchbegriff in `scripts/beispielbilder_suche.json` eintragen. Franchises bekommen neutrale Begriffe, z. B. `hello_kitty` → „cute plush toy pink“, `marvel` → „comic books stack“.

Dann `python scripts/hole_beispielbilder.py vorschlaege <scratchpad-ordner> …` und die Bögen ansehen. Pro Stichwort das passendste Foto wählen, bei Franchises ohne erkennbares Logo oder Figur. Danach `… uebernehmen <ordner> <auswahl.json>`.

Run: `.venv/Scripts/python -m pytest -q`
Expected: Nur `test_bereiche_swift_aktuell` schlägt fehl, der Foto-Test ist grün.

- [ ] **Step 6: App-Tabelle neu erzeugen und alles prüfen**

Run: `.venv/Scripts/python scripts/bereiche_fuer_app.py; .venv/Scripts/python -m pytest -q`
Expected: alles grün

Prompt-Länge messen: `len(vokabular_text())`. Vorher waren es 4918 Zeichen. Die neue Zahl ins Commit-Body schreiben.

- [ ] **Step 7: Commit**

```bash
git add app/vokabular.py tests/test_vokabular.py scripts/beispielbilder_suche.json app/static/beispielbilder ios/GeschenkeCore/Sources/GeschenkeCore/Bereiche.swift
git commit -m "Add clothing groups and franchises to vocabulary (v4)"
```

---

### Task 2: Ranking und Ausschluss kennen Gruppen

**Files:**
- Modify: `app/ranking.py` (`bewerte`, `ist_ausgeschlossen`)
- Test: `tests/test_ranking_bereich.py`

**Interfaces:**
- Consumes: `mit_gruppen`, `THEMA_GRUPPE` aus Task 1
- Produces: `GRUPPE_ANTEIL = 0.7` in `app/ranking.py`

Regel für `bewerte`:
1. `tags = mit_gruppen(p.themen) | set(p.lebenslagen)`.
2. Direkte Treffer zählen voll wie bisher.
3. Gibt es keinen direkten Treffer, zählt der stärkste Wunsch, dessen `THEMA_GRUPPE.get(w.tag)` in `tags` liegt, mal 0,7.
4. Gibt es auch das nicht, gilt wie bisher der Bereich mal 0,4.
5. Bonus für Persönliches unverändert.

`ist_ausgeschlossen`: `art == "thema"` prüft `wert in mit_gruppen(p.themen)`, statt nur `p.themen`. Der Text-Check bleibt.

- [ ] **Step 1: Failing tests**

Produkte im Stil der vorhandenen Tests in `tests/test_ranking_bereich.py` bauen.

```python
def test_gruppen_wunsch_trifft_kind_voll():          # Wunsch schuhe, Produkt ["stiefel"] → 1.0 * gewicht
def test_geschwister_in_gruppe_zaehlt_0_7():         # Wunsch stiefel, Produkt ["sneaker"] → 0.7
def test_gruppe_schlaegt_bereich():                  # Wunsch stiefel: ["sneaker"] > ["vintage"] (0.4)
def test_direkter_treffer_schlaegt_gruppe():         # Wunsch stiefel: ["stiefel"] > ["sneaker"]
def test_ausschluss_gruppe_trifft_altes_produkt():   # thema:schuhe schließt ["sneaker"] aus
def test_ausschluss_kind_laesst_geschwister_durch(): # thema:stiefel schließt ["sneaker"] nicht aus
```

Die Kommentare geben die exakten Asserts vor. Die Titel der Testprodukte enthalten das Stichwort nicht, damit nur die Tags geprüft werden.

- [ ] **Step 2: Fehlschlag sehen**

Run: `.venv/Scripts/python -m pytest tests/test_ranking_bereich.py -q`
Expected: FAIL in den neuen Tests

- [ ] **Step 3: Umsetzen wie oben beschrieben**

- [ ] **Step 4: Alles grün**

Run: `.venv/Scripts/python -m pytest -q`
Expected: PASS. Bestehende Ranking- und Ausschluss-Tests bleiben unverändert grün.

- [ ] **Step 5: Commit**

```bash
git add app/ranking.py tests/test_ranking_bereich.py
git commit -m "Rank and exclude by clothing groups"
```

---

### Task 3: Tempo bei 25.000 Produkten und Größenvarianten

**Files:**
- Modify: `app/ranking.py` (`ist_ausgeschlossen`, Hilfsfunktionen)
- Modify: `app/katalog/regeln.py` (`fasse_varianten_zusammen`)
- Create: `scripts/miss_tempo.py`
- Test: `tests/test_regeln.py`, `tests/test_ranking.py`

**Interfaces:**
- Produces: `def varianten_schluessel(p: QuellProdukt) -> str | None` in `app/katalog/regeln.py`

Gemessen am 06.11.: `kandidaten()` braucht mit „eigenschaft:alkohol“ und „farbe:schwarz“ 0,48 s bei 2457 Produkten. Ziel: höchstens 0,5 s bei 25.000 Produkten auf demselben Rechner.

Weg dorthin:
- Je Eigenschaft ein vorkompilierter Sammel-Regex `re.compile(r"\b(?:" + "|".join(muster) + ")")`. Die Muster selbst ändern sich nicht.
- Der kleingeschriebene Text kommt per `functools.lru_cache(maxsize=None)` über `(titel, beschreibung)`, damit `.lower()` nicht bei jeder Anfrage neu läuft.
- Farb- und Wort-Regexe ebenfalls vorkompiliert.

- [ ] **Step 1: Messskript `scripts/miss_tempo.py`**

Es lädt `lade_katalog`, vervielfacht ihn auf 25.000 Produkte (Kopien mit `id` + Zähler) und misst `kandidaten()` mit dem Profil `kochen` und den Ausschlüssen alkohol und schwarz, Mittel aus 5 Läufen. Ausgabe: `s je Anfrage: X bei N`.

Run: `.venv/Scripts/python -X utf8 scripts/miss_tempo.py`
Expected: rund 4–5 s (Ausgangswert festhalten)

- [ ] **Step 2: Failing test für Varianten in `tests/test_regeln.py`**

```python
def test_groessen_ohne_gruppe_werden_eine_karte():
    # gleicher Shop, Titel "Hoodie Classic – Größe M" / "Hoodie Classic - L" / "Hoodie Classic (XL)",
    # verschiedene Preise → eine Karte, die günstigste
def test_gleicher_titel_anderer_shop_bleibt_getrennt():
def test_varianten_gruppe_aus_feed_hat_vorrang():
```

`varianten_schluessel(p)` gibt `p.varianten_gruppe` zurück, wenn vorhanden. Sonst `f"{p.shop}|{titel}"`, wobei aus dem kleingeschriebenen Titel Größenangaben am Ende entfernt werden: `größe`/`gr.`, `xxs–3xl`, `s/m/l`, zwei Ziffern oder zwei Ziffern mit Schrägstrich, auch in Klammern oder nach – oder -. `fasse_varianten_zusammen` gruppiert nach diesem Schlüssel.

- [ ] **Step 3: Fehlschlag sehen, umsetzen, grün**

Run: `.venv/Scripts/python -m pytest tests/test_regeln.py -q` → zuerst FAIL, nach der Umsetzung PASS

- [ ] **Step 4: Ausschluss beschleunigen wie oben**

Run: `.venv/Scripts/python -m pytest -q`
Expected: PASS. Alle Ausschluss-Tests unverändert grün (Grundbaustein 3).

Run: `.venv/Scripts/python -X utf8 scripts/miss_tempo.py`
Expected: `s je Anfrage` ≤ 0,5 bei 25000

- [ ] **Step 5: Commit**

```bash
git add app/ranking.py app/katalog/regeln.py scripts/miss_tempo.py tests/test_regeln.py
git commit -m "Speed up exclusion filter and merge size variants"
```

---

### Task 4: Mistral als Arbeiter in der Verschlagwortung

**Files:**
- Create: `app/katalog/mistral.py`
- Modify: `app/config.py`, `app/katalog/verschlagworten.py` (`_stapel`), `scripts/build_katalog.py` (`arbeiter`), `.github/workflows/katalog.yml`
- Test: `tests/test_mistral.py`, `tests/test_verschlagworten.py`

**Interfaces:**
- Produces:
  - `MISTRAL_URL = "https://api.mistral.ai/v1/chat/completions"`
  - `async def frage_json_mistral(system: str, nutzer: str, *, modell: str, max_tokens: int = 4000, zeitlimit: float = 120) -> dict`. Bei 429, 5xx, Netzfehler oder zweimal kaputtem JSON wirft sie `app.ki.KiUeberlastet`.
  - Settings: `mistral_api_key: str = ""`, `mistral_modell: str = "mistral-small-latest"`, `mistral_arbeiter: int = 3`
  - Arbeiter-Schlüssel `"mistral:<modell>#<n>"`. `_stapel` erkennt das Präfix `mistral:` und ruft `frage_json_mistral(modell=<modell>)`, alles andere geht wie bisher an `frage_json`.
  - `PAUSE_MISTRAL = 3` in `scripts/build_katalog.py`

Schnittstelle wie OpenAI: Bearer-Header, `response_format: {"type": "json_object"}`, `temperature: 0.3`. Geloggt werden nur Statuscodes, kein Rumpf.

- [ ] **Step 1: Failing tests (respx, wie `tests/test_ki.py`)**

```python
async def test_mistral_liefert_json():           # 200 mit content '{"a":1}' → {"a": 1}; Header Bearer settings.mistral_api_key
async def test_mistral_429_wirft_ueberlastet():
async def test_mistral_kaputtes_json_einmal_wiederholt():   # "x", '{"b":2}' → {"b": 2}, 2 Aufrufe
async def test_stapel_mit_mistral_arbeiter_fragt_mistral(monkeypatch):  # _stapel(ps, "mistral:m#0") ruft frage_json_mistral(modell="m"), nicht frage_json
def test_arbeiter_ohne_mistral_schluessel_wie_bisher(monkeypatch):      # mistral_api_key="" → nur Groq-Modelle ki_modelle[1:]
def test_arbeiter_mit_mistral_schluessel(monkeypatch):                  # 3 Schlüssel "mistral:mistral-small-latest#0..2", Pause 3
```

- [ ] **Step 2: Fehlschlag sehen**

Run: `.venv/Scripts/python -m pytest tests/test_mistral.py tests/test_verschlagworten.py -q`
Expected: FAIL (Modul fehlt)

- [ ] **Step 3: Umsetzen**

Workflow `katalog.yml`:
- `MISTRAL_API_KEY: ${{ secrets.MISTRAL_API_KEY }}` in die env des Bau-Schritts
- `timeout-minutes: 350`
- `KATALOG_MAX_STAPEL: "2000"` als env

Ist das Secret leer, verhält sich alles wie heute.

- [ ] **Step 4: Grün**

Run: `.venv/Scripts/python -m pytest -q`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/katalog/mistral.py app/config.py app/katalog/verschlagworten.py scripts/build_katalog.py .github/workflows/katalog.yml tests/test_mistral.py tests/test_verschlagworten.py
git commit -m "Add Mistral as catalog tagging worker"
```

---

### Task 5: Mistral-Stichprobe (braucht Lukas Schlüssel)

**Files:** keine im Repo. Wegwerfskript im Scratchpad.

- [ ] **Step 1: Luka um den Schlüssel bitten.** Er trägt ihn selbst in die lokale `.env` als `MISTRAL_API_KEY=…` ein. Die Datei steht nicht im Git, Claude zeigt den Schlüssel nie an.

- [ ] **Step 2: Modelle prüfen**

`GET https://api.mistral.ai/v1/models` mit dem Schlüssel aufrufen. Verfügbare Modelle und die Rate-Limit-Header notieren.

- [ ] **Step 3: Stichprobe**

Dieselben 100 Produkte, davon 50 aus Kleidungs- oder Fanshops, sobald welche gesammelt sind, sonst gemischt, gehen per `_stapel` an `mistral:mistral-small-latest#0` und an `qwen/qwen3.8-27b`. Je Modell zählen:
- Produkte ohne Themen
- Anteil der neuen v4-Stichwörter
- fehlende Note
- JSON-Fehler
- Dauer je Stapel
- mittlere Note

Wenn Zeit bleibt, zusätzlich `mistral-medium-latest`.

- [ ] **Step 4: Entscheiden**

Ein Mistral-Modell besteht, wenn es höchstens so oft „ohne Themen“ liefert wie Qwen, keine JSON-Fehler bei 5 Stapeln hat und die neuen Stichwörter vergibt. Das beste bestandene Modell wird `mistral_modell`. Besteht keins, läuft es nur mit Groq weiter, und Luka erfährt, dass die Woche dann nicht reicht.

- [ ] **Step 5: Ergebnis festhalten**

Gemessene Limits und Ergebnis in `Wissen/gratis-llm-apis.md` (Vault) eintragen. Nach Lukas Okay das GitHub-Secret setzen: `gh secret set MISTRAL_API_KEY` mit dem Wert aus `.env`, ohne Ausgabe.

---

### Task 6: ≈ 30.000 neue Produkte sammeln

**Files:**
- Modify: `katalog/shops.json`, neu `katalog/quellen/shop-*.json`

Ausgangsstand: 128 Shops, **4398 Produkte bestehen den Regel-Filter**. Ziel: **≥ 34.400**.

- [ ] **Step 1: Kandidaten suchen**

Per Websuche rund 250 deutsche Shops sammeln, Schwerpunkte:
- Schuhe: Fach- und Markenhändler
- Mode: Marken-Onlineshops, Fair-Fashion, Trachten, Bademode
- Schmuck und Uhren
- Taschen
- Lizenz- und Fanartikel: offizielle Markenshops, große Spielwaren- und Merch-Händler, Anime-Shops mit Lizenzware
- übrige Bereiche zum Auffüllen

Ausgeschlossen sind Marktplätze (Amazon, eBay, Otto-Marktplatz, Temu, Shein, Wish, AliExpress) und Shopify.

- [ ] **Step 2: Prüfen**

Run: `.venv/Scripts/python -X utf8 scripts/sammle_shops.py --pruefe <url> …`

Nur „lesbar“ kommt mit `bereich` in `shops.json`. `bereich` ist ein Schlüssel aus `BEREICHE`, Kleidung = `mode`, Fanartikel = `franchises`.

- [ ] **Step 3: Sammeln (im Hintergrund, dauert Stunden)**

Run: `.venv/Scripts/python -X utf8 scripts/sammle_shops.py --ziel 150`

Danach die Shops, die schon bei 30 voll waren, nochmals mit `--nur … --ziel 150`.

- [ ] **Step 4: Zählen**

Dasselbe Zählskript wie für den Ausgangsstand (Regel-Filter über alle Quellen und danach `fasse_varianten_zusammen`).
Expected: ≥ 34.400. Fehlt etwas, mit weiteren Shops wieder ab Step 1. Stichprobe ansehen: 30 zufällige Kleidungs- und Fanprodukte, kein Ramsch, keine Fälschungen. Auffällige Shops aus `shops.json` entfernen.

- [ ] **Step 5: Größen und Speicher prüfen**

Größte Datei in `katalog/quellen` unter 50 MB. Gesamtgröße notieren.

- [ ] **Step 6: Commit**

```bash
git add katalog/shops.json katalog/quellen
git commit -m "Collect ~30000 new products from new shops"
```

---

### Task 7: Großer Lauf, Messungen, Auslieferung

**Files:** `katalog/katalog.json` (erzeugt), Vault-Notizen

- [ ] **Step 1: Bauen**

Branch pushen (mit Lukas Okay), dann `gh workflow run katalog.yml --ref katalog-gross`.

Läufe so lange wiederholen (Handläufe erlaubt), bis im Log `noch_offen: 0` steht. Spätestens am 12.11. muss der letzte Lauf durch sein. Nach jedem Lauf melden:
- `katalog`
- `note_raus`
- `noch_offen`

Der Bot committet auf den Branch. Vor eigenen Commits erst `git pull`.

- [ ] **Step 2: Zahlen für Luka**

Gesamt sichtbar und neue sichtbar, Ziel ≈ 20.000. Liste der Gruppen und Franchise-Stichwörter mit weniger als 5 zeigbaren Produkten.

- [ ] **Step 3: Tempo und Speicher mit dem echten Katalog**

Run: `.venv/Scripts/python -X utf8 scripts/miss_tempo.py`. Anfrage ≤ 0,5 s.

Speicher: Server lokal starten (`uvicorn app.main:app`), nach dem Laden die RSS des Prozesses ablesen (PowerShell `Get-Process`). Expected: < 400 MB, damit Luft bis 512 MB bleibt. Wird es knapp, nur zeigbare Produkte im Speicher halten (macht `lade_katalog` schon) und die Felder prüfen.

`katalog.json` < 50 MB.

- [ ] **Step 4: Chat-Prompt live prüfen**

Ein Gespräch lokal mit echtem Groq führen, 5 Züge, „mag Hello Kitty und trägt gern Stiefel“. Kein 429, erkannt werden `hello_kitty` und `stiefel`. Die Karten zeigen Stiefel vor anderen Schuhen.

- [ ] **Step 5: Prüfen und Abgabe**

Komplette Tests: pytest, Swift-Kern- und App-Build in CI auf dem Branch (`gh workflow run ios-build.yml --ref katalog-gross -f runner=macos-15`). Danach Review des ganzen Branches. Luka die Zahlen nennen und um das Merge-Okay bitten. Nach dem Merge Render live prüfen (`/karten` mit „hello_kitty“), siehe Hinweis zum Auto-Deploy in der Projektnotiz.

- [ ] **Step 6: Vault**

`Projekte/geschenke-app.md` und die Index-Zeile aktualisieren (Skill `obsidian-uebergabe`).
