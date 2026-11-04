# Design-Vorschau „Zuhause“ – Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Stand 04.11. abends: noch nicht umsetzen.** Luka will erst weiter am Design arbeiten. Seitdem entschieden (DESIGN.md 5 und 6a): Leiste Start, Wischen, Merkliste, **Einstellungen** (Profile über die Startseite), neuer Startbildschirm mit Geschenk-Logo und Ladering. Task 4 vor der Umsetzung entsprechend überarbeiten und den Startbildschirm als eigene Aufgabe ergänzen.

**Goal:** Ein neues Design „Zuhause“ mit zwei Farbwelten (Abendlicht und Hell), das automatisch dem Dunkelmodus des iPhones folgt oder per Schalter festgelegt wird, sowie eine Leiste unten (Start, Wischen, Merkliste, Profile) und eine neue Startseite nach „Coco-Test 2“ ohne Kacheln, als Vorschau auf Branch `design-neu`.

**Architecture:** Paletten, Erscheinungs-Logik und Begrüßung liegen testbar im Kern (`GeschenkeCore`). Eine neue Wurzel-View liest den Dunkelmodus des Systems, wählt daraus die Palette und setzt `preferredColorScheme`. Die Motive werden per Python-Skript aus den Coco-SVGs je Farbwelt fertig gefärbt und als SVG mit Hell/Dunkel-Variante in einen neuen Asset-Katalog geschrieben; iOS wählt die Variante selbst. Im Design „Zuhause“ zeigt die Wurzel eine `TabView` mit eigener Startseite (`ZuhauseStartView`). Alle 8 alten Designs behalten `NavigationStack { StartView() }` und bleiben unverändert.

**Tech Stack:** SwiftUI (iOS 26), XcodeGen, Swift-Paket GeschenkeCore (XCTest, CI unter Linux), Python 3 (Standardbibliothek, unittest), GitHub Actions.

**Spec:** Kein eigenes Spec-Dokument. Grundlage: `docs/superpowers/plans/2026-11-03-design-neu.md` (Fahrplan; „Feste Vorgaben“ und „Worauf beim Prüfen achten“) und das von Luka abgenommene Muster `.superpowers/zeigen/ansichten/2026-11-04-coco-test/` und dessen von Luka als „deutlich besser“ bewertete zweite Fassung `2026-11-04-coco-test-2/` (Linie Abendlicht Cognac; Leiste behalten, Kacheln weg) (`bauen.py` mit `FARBEN` und den CSS-Farben, `zerlegen.py`). Lukas Entscheidungen vom 04.11.: Wechsel „automatisch nach Dunkelmodus + Schalter in den Einstellungen“; „Vorschau-Einbau: nur die beiden Farbwelten mit Automatik und Schalter, die Startseite mit den 6 Coco-Motiven. Alles auf Branch design-neu, kein Merge.“

## Global Constraints

- Branch `design-neu`, kein Merge nach `main` (nur mit Lukas Okay). Commits gehen auf `design-neu`.
- Alle Grundbausteine aus `CLAUDE.md` gelten. Relevant: Nr. 10 (Erscheinung nur in `appdaten.json` auf dem Handy), Nr. 11 (Coco Material ist CC0, kostenlos).
- Kontrast: Text/Karte, Text/Hintergrund, aufAkzent/Akzent, Preis/Karte jeweils mindestens 4,5 (`kontrast()`), für **beide** Zuhause-Paletten.
- Dynamic Type muss weiter funktionieren: nur Textstile (`.headline`, `.title3` …), keine festen Schriftgrößen für neuen Text.
- Umlaute in allen Texten korrekt.
- Die 8 bisherigen Designs sehen genauso aus wie vorher. Neues Verhalten nur bei `Look.stil == .zuhause`.
- Kein ✨ und keine Großbuchstaben-Überschriften im Zuhause-Stil (`docs/design/ki-look-checkliste.md`).
- Neue Felder in `AppDaten` immer mit `decodeIfPresent` lesen.
- Kein lokaler Swift-Compiler: Swift-Code wird nur in CI geprüft (Kern: `ios-core-tests.yml` läuft bei jedem Push auf `ios/GeschenkeCore/**`; App: `ios-build.yml` auf Branches nur per `gh workflow run`). Vor jedem Push den Code einmal gezielt auf Kompilierfehler durchlesen, jede CI-Runde kostet.
- Branch-Builds landen nicht automatisch auf dem Handy (Release nur von `main`). Luka installiert die IPA aus dem Actions-Artefakt `Geschenke-ipa` per SideStore.
- Python-Skripte mit `python -X utf8` ausführen.

## Review Focus

1. **Zurück auf „Automatisch“:** Wer von „Abendlicht“ auf „Automatisch“ stellt, muss sofort wieder dem System folgen. `preferredColorScheme(nil)` setzt in manchen iOS-Versionen nicht zurück. Prüfung auf dem iPhone (Task 3, Schritt 6). Falls es hakt: stattdessen `overrideUserInterfaceStyle` aller Fenster der `UIWindowScene` setzen (`.unspecified`/`.light`/`.dark`).
2. **Dunkelmodus wechselt, während die App offen ist** (Kontrollzentrum oder Zeitplan am Abend): Farben und Motive müssen ohne Neustart wechseln. Prüfung auf dem iPhone (Task 3, Schritt 6).
3. **Motiv bleibt leer oder schwarz:** iOS zeichnet SVGs aus dem Asset-Katalog mit eingeschränktem Funktionsumfang (kein CSS, keine `var()`, Maße in `mm` unsicher). Abgesichert durch `test_nur_attribute` (Task 2) und Sichtprüfung auf dem iPhone (Task 4).
4. **Große Schrift:** Begrüßung, „Geschenk finden“ und Kacheltitel dürfen bei Schriftstufe „Sehr groß“ nicht abgeschnitten werden oder mit den Motiven kollidieren. Prüfung per Bildschirmfoto bei „Sehr groß“ (Task 4, Schritt 5).
5. **Leere Zustände:** keine Profile, Merkliste leer. „Zuletzt gemerkt“ und der Reiter „Wischen“ zeigen dann einen Hinweis mit Weg zur Suche statt einer leeren Fläche (Task 4).
6. **Alte Daten:** Eine `appdaten.json` ohne Feld `erscheinung` muss weiter geladen werden, sonst landen Profile in `appdaten.kaputt-*.json`. Abgesichert durch `testAlteDatenOhneErscheinung` (Task 1).

---

## Dateien

| Datei | Aufgabe |
|---|---|
| `ios/GeschenkeCore/Sources/GeschenkeCore/Designs.swift` (ändern) | `DesignStil.zuhause`, zwei Zuhause-Paletten, Auswahl nach Erscheinung |
| `ios/GeschenkeCore/Sources/GeschenkeCore/Zuhause.swift` (neu) | `Erscheinung`, `begruessung(stunde:)` |
| `ios/GeschenkeCore/Sources/GeschenkeCore/AppDaten.swift` (ändern) | Feld `erscheinung` |
| `ios/GeschenkeCore/Tests/GeschenkeCoreTests/DesignsTests.swift`, `ZuhauseTests.swift` (neu), `AppDatenTests.swift` | Tests |
| `ios/werkzeuge/coco/` (neu) | `zerlegen.py` (Kopie), `faerben.py`, `test_faerben.py`, `svg/` (6 Originale), `LIZENZ.md` |
| `ios/Geschenke/Assets.xcassets/` (neu, erzeugt) | 6 Bildsätze `coco-*` mit Hell/Dunkel-SVG |
| `ios/Geschenke/Wurzel.swift` (neu) | Palette aus Systemmodus + Erscheinung, Wurzel-View |
| `ios/Geschenke/ZuhauseTabs.swift` (neu) | Leiste und die Reiter Wischen und Profile |
| `ios/Geschenke/ZuhauseStartView.swift` (neu) | Startseite im Zuhause-Stil |
| `ios/Geschenke/GeschenkeApp.swift`, `AppZustand.swift`, `Look.swift`, `KartenView.swift`, `StartView.swift` (ändern) | Einbau |

---

### Task 1: Kern – Zuhause-Paletten, Erscheinung, Begrüßung

**Files:**
- Modify: `ios/GeschenkeCore/Sources/GeschenkeCore/Designs.swift`
- Create: `ios/GeschenkeCore/Sources/GeschenkeCore/Zuhause.swift`
- Modify: `ios/GeschenkeCore/Sources/GeschenkeCore/AppDaten.swift`
- Test: `ios/GeschenkeCore/Tests/GeschenkeCoreTests/DesignsTests.swift`, `ZuhauseTests.swift` (neu), `AppDatenTests.swift`

**Interfaces:**
- Produces:
  - `DesignStil.zuhause`
  - `Designs.zuhauseID: String` (`"zuhause"`), `Designs.zuhauseAbend: Palette`, `Designs.zuhauseHell: Palette` (beide `id: "zuhause"`, `name: "Zuhause"`, `stil: .zuhause`)
  - `Designs.alle` endet mit `zuhauseAbend` (Standard bleibt `"nachtblau"`)
  - `Designs.palette(_ id: String, erscheinung: Erscheinung, systemDunkel: Bool) -> Palette`
  - `Designs.erzwingtHell(_ id: String, erscheinung: Erscheinung) -> Bool?` (`nil` = System folgen)
  - `public enum Erscheinung: String, CaseIterable, Identifiable { case automatisch, hell, abendlicht }` mit `id`, `titel` („Automatisch“, „Hell“, „Abendlicht“), `static func aus(_ rohwert: String) -> Erscheinung` (unbekannt → `.automatisch`)
  - `public func begruessung(stunde: Int) -> String`
  - `AppDaten.erscheinung: String = "automatisch"`

- [ ] **Step 1: Tests schreiben**

In `DesignsTests.swift`: `testAchtDesignsStandardZuerst` umbenennen in `testDesignsStandardZuerstZuhauseZuletzt` und die Liste auf `["nachtblau", "wald", "bordeaux", "polarlicht", "graphit", "mint", "deco", "pinnwand", "zuhause"]` ändern. In `testAllesLesbar` über `Designs.alle + [Designs.zuhauseHell]` laufen. Neu:

```swift
func testZuhauseFolgtErscheinung() {
    let p = { Designs.palette("zuhause", erscheinung: $0, systemDunkel: $1) }
    XCTAssertFalse(p(.automatisch, true).hell)
    XCTAssertTrue(p(.automatisch, false).hell)
    XCTAssertTrue(p(.hell, true).hell)
    XCTAssertFalse(p(.abendlicht, false).hell)
    XCTAssertEqual(p(.hell, true).stil, .zuhause)
    XCTAssertEqual(p(.abendlicht, false).hintergrund, 0x23160C)
    XCTAssertEqual(p(.hell, false).hintergrund, 0xEFE6D6)
    // Andere Designs ignorieren die Erscheinung.
    XCTAssertEqual(Designs.palette("mint", erscheinung: .abendlicht, systemDunkel: true).id, "mint")
    XCTAssertEqual(Designs.palette("gibtsnicht", erscheinung: .hell, systemDunkel: false).id, "nachtblau")
}

func testErzwingtHell() {
    XCTAssertNil(Designs.erzwingtHell("zuhause", erscheinung: .automatisch))
    XCTAssertEqual(Designs.erzwingtHell("zuhause", erscheinung: .hell), true)
    XCTAssertEqual(Designs.erzwingtHell("zuhause", erscheinung: .abendlicht), false)
    XCTAssertEqual(Designs.erzwingtHell("wald", erscheinung: .automatisch), false)
    XCTAssertEqual(Designs.erzwingtHell("mint", erscheinung: .abendlicht), true)
}
```

Neue Datei `ZuhauseTests.swift`:

```swift
func testErscheinungAusRohwert() {
    XCTAssertEqual(Erscheinung.aus("abendlicht"), .abendlicht)
    XCTAssertEqual(Erscheinung.aus("quatsch"), .automatisch)
}

func testBegruessung() {
    XCTAssertEqual(begruessung(stunde: 4), "guten abend.")
    XCTAssertEqual(begruessung(stunde: 5), "guten morgen.")
    XCTAssertEqual(begruessung(stunde: 10), "guten morgen.")
    XCTAssertEqual(begruessung(stunde: 11), "guten tag.")
    XCTAssertEqual(begruessung(stunde: 17), "guten tag.")
    XCTAssertEqual(begruessung(stunde: 18), "guten abend.")
}
```

In `AppDatenTests.swift`:

```swift
func testAlteDatenOhneErscheinung() throws {
    let json = #"{"profile":[],"merkliste":[],"design":"zuhause","schriftgroesse":"normal"}"#
    let daten = try JSONDecoder().decode(AppDaten.self, from: Data(json.utf8))
    XCTAssertEqual(daten.design, "zuhause")
    XCTAssertEqual(daten.erscheinung, "automatisch")
}

func testErscheinungRundreise() throws {
    let datei = tempDatei()
    var daten = AppDaten()
    daten.erscheinung = "abendlicht"
    try AppDatenSpeicher(datei: datei).speichern(daten)
    XCTAssertEqual(AppDatenSpeicher(datei: datei).laden().erscheinung, "abendlicht")
}
```

- [ ] **Step 2: Implementieren**

Paletten (Werte aus dem abgenommenen Muster; `aufAkzent` im Hellen dunkel, weil `#FFF6E6` auf `#C2721E` nur ca. 3,4 erreicht):

| Feld | `zuhauseAbend` (hell: false) | `zuhauseHell` (hell: true) |
|---|---|---|
| hintergrund | `0x23160C` | `0xEFE6D6` |
| karte | `0x452C1B` | `0xF8F1E5` |
| rand | `0x5E3F27` | `0xE0D0B5` |
| text | `0xF1E3C6` | `0x23160C` |
| akzent | `0xC2721E` | `0xC2721E` |
| aufAkzent | `0x23160C` | `0x23160C` |
| preis | `0xEFB249` | `0x9A3A24` |

`palette(_:erscheinung:systemDunkel:)`: nur für `zuhauseID` nach Erscheinung wählen (`.automatisch` → `systemDunkel`), sonst `palette(id)`. `erzwingtHell`: Zuhause → `nil`/`true`/`false`, sonst `palette(id).hell`. `begruessung`: 5–10 Uhr „guten morgen.“, 11–17 „guten tag.“, sonst „guten abend.“. In `AppDaten` das Feld in `CodingKeys` und `init(from:)` mit `?? "automatisch"` ergänzen.

- [ ] **Step 3: Pushen und CI prüfen**

```bash
git add ios/GeschenkeCore && git commit -m "Add Zuhause palettes, appearance and greeting to core"
git push origin design-neu
gh run watch $(gh run list --workflow ios-core-tests.yml --branch design-neu --limit 1 --json databaseId -q '.[0].databaseId') --exit-status
```

Erwartet: Lauf grün, darin `Executed … tests, with 0 failures`. Bei Rot: Log mit `gh run view --log-failed` lesen, beheben, erneut pushen.

---

### Task 2: Gefärbte Coco-Motive als Asset-Katalog

**Files:**
- Create: `ios/werkzeuge/coco/zerlegen.py` (unveränderte Kopie aus `.superpowers/zeigen/ansichten/2026-11-04-coco-test/`)
- Create: `ios/werkzeuge/coco/svg/` (die 6 Original-SVGs aus demselben Ordner `svg/`: `animals_cat_sleeping2`, `unwrap_gift_3`, `christmas_holly_3`, `present_5`, `family_love-7`, `food_tea`)
- Create: `ios/werkzeuge/coco/faerben.py`, `ios/werkzeuge/coco/test_faerben.py`, `ios/werkzeuge/coco/LIZENZ.md` (ein Satz: Motive von cocomaterial.com, CC0)
- Create (erzeugt): `ios/Geschenke/Assets.xcassets/Contents.json`, `ios/Geschenke/Assets.xcassets/coco-<name>.imageset/{<name>-hell.svg, <name>-abend.svg, Contents.json}`

**Interfaces:**
- Consumes: `teilpfade`, `loecher`, `innen` aus `zerlegen.py`
- Produces: Bildnamen für die App: `coco-katze` (animals_cat_sleeping2), `coco-geschenk` (unwrap_gift_3), `coco-kranz` (christmas_holly_3), `coco-stapel` (present_5), `coco-familie` (family_love-7), `coco-tee` (food_tea)
- `faerbe(svg: str, plan: dict, farben: dict[str, str]) -> str` und `main() -> None` in `faerben.py`

- [ ] **Step 1: Tests schreiben** (`test_faerben.py`, unittest)

- `test_nur_attribute`: Für alle 6 Motive × beide Varianten enthält `faerbe(...)` weder `var(` noch `style=` noch `mm"`.
- `test_farben_der_variante`: Katze Abend enthält `fill="#D7843A"` und `fill="#7B5930"`, Katze Hell enthält `fill="#D07A2C"` und `fill="#23160C"`.
- `test_luecke_bleibt_leer`: Bei `unwrap_gift_3` kommt `teilpfade(d)[30]["d"]` des Linienpfads in der Ausgabe nicht vor (Flächen nutzen die absolut umgeschriebenen Teilpfade, der Linienpfad behält sein Original-`d`). Gegenprobe: `teilpfade(d)[35]["d"]` (Haut) kommt vor. Gleiches für `present_5`, Teil 75.
- `test_masse_aus_viewbox`: Das Wurzel-`<svg>` der Katze hat `width="163.52823" height="106.78658"`.
- `test_contents_json`: Nach `main()` in einen Temp-Ordner (Ausgabeordner als Parameter `main(ziel: Path)`) hat `coco-katze.imageset/Contents.json` zwei Bilder, das `-abend.svg` mit `"appearances": [{"appearance": "luminosity", "value": "dark"}]`, und `"properties": {"preserves-vector-representation": true}`.

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

Run: `python -X utf8 -m unittest discover -s ios/werkzeuge/coco -v`
Erwartet: FAIL (`faerben` fehlt).

- [ ] **Step 3: `faerben.py` implementieren**

`FARBEN` aus `bauen.py` übernehmen, mit einer Ausnahme: Kranz im Abendlicht Grundfarbe `moos` statt `moosdunkel` (Feld `basis_abend`). Färbelogik wie `motiv()` in `bauen.py` (Löcher füllen, Lücken auslassen, winzige Löcher erben), aber nur mit Attributen: Flächen als `fill="#hex"`, `fill="#fff"` → Basisfarbe, `fill="#030303"` → Linienfarbe, Wurzel-`<svg>` bekommt `fill="<linie>"` (für Linienpfade ohne `fill`) und `width`/`height` = Breite/Höhe aus `viewBox` ohne Einheit. Farbtabellen je Variante (Hex aus den CSS-Variablen in `bauen.py`):

- `abend`: linie `#7B5930`, rot `#C9573A`, kupfer `#D7843A`, licht `#EFB249`, haut `#E2B98C`, braun `#7B5930`, moos `#86A04B`, moosdunkel `#5F7A33`
- `hell`: linie `#23160C`, rot `#BE4A2E`, kupfer `#D07A2C`, licht `#EFB249`, haut `#EBC499`, braun `#7B5930`, moos `#7C9A42`, moosdunkel `#566F2D`

`main(ziel=Path("ios/Geschenke/Assets.xcassets"))` schreibt Wurzel-`Contents.json` (`{"info": {"author": "xcode", "version": 1}}`) und je Motiv einen Bildsatz; das `-hell.svg` ist der Eintrag ohne `appearances`.

- [ ] **Step 4: Tests laufen lassen**

Run: `python -X utf8 -m unittest discover -s ios/werkzeuge/coco -v`
Erwartet: 5 Tests OK.

- [ ] **Step 5: Assets erzeugen und Luka zeigen**

Run: `python -X utf8 ios/werkzeuge/coco/faerben.py` → 6 Ordner `coco-*.imageset` mit je 3 Dateien.
Ansicht `.superpowers/zeigen/ansichten/2026-11-04-app-motive/index.html`: zwei Spalten (Karte `#452C1B` / `#F8F1E5`), darin die 12 erzeugten SVGs per `<img src="…">` (relativer Pfad, die SVGs in den Ansichtsordner kopieren). Anmelden mit `python -X utf8 .superpowers/zeigen/anmelden.py 2026-11-04-app-motive "Motive für die App"`. Per Playwright-Bildschirmfoto prüfen, dass alle 12 Motive gefärbt wie im Coco-Test erscheinen (keine schwarzen Flächen, Arm-Lücke zeigt Kartenfarbe).

- [ ] **Step 6: Commit**

```bash
git add ios/werkzeuge/coco ios/Geschenke/Assets.xcassets
git commit -m "Add Coco illustration generator and colored assets"
```

---

### Task 3: Erscheinung in der App (Wurzel, Schalter, Hintergrund)

**Files:**
- Create: `ios/Geschenke/Wurzel.swift`
- Modify: `ios/Geschenke/GeschenkeApp.swift`, `ios/Geschenke/AppZustand.swift`, `ios/Geschenke/Look.swift` (`DesignHintergrund`), `ios/Geschenke/KartenView.swift:62-73` (`rahmen`), `ios/Geschenke/StartView.swift` (`EinstellungenView`)

**Interfaces:**
- Consumes: aus Task 1 `Designs.palette(_:erscheinung:systemDunkel:)`, `Designs.erzwingtHell`, `Erscheinung`, `AppDaten.erscheinung`, `DesignStil.zuhause`
- Produces: `AppZustand.setzeErscheinung(_ erscheinung: Erscheinung)`; `struct Wurzel: View`

- [ ] **Step 1: `AppZustand.setzeErscheinung(_:)`** – setzt `daten.erscheinung = erscheinung.rawValue` und ruft `sichern()`.

- [ ] **Step 2: `Wurzel.swift`**

`struct Wurzel: View` mit `@EnvironmentObject zustand` und `@Environment(\.colorScheme)`. Übernimmt den gesamten bisherigen Inhalt von `WindowGroup` aus `GeschenkeApp` (NavigationStack, Sheet, environmentObject, dynamicTypeSize, tint, fontDesign). Unterschiede:
- `private func aktuellePalette() -> Palette` berechnet `Designs.palette(zustand.daten.design, erscheinung: Erscheinung.aus(zustand.daten.erscheinung), systemDunkel: colorScheme == .dark)`, weist sie `Look.palette` zu und gibt sie zurück. Im `body` als erste Zeile `let palette = aktuellePalette()` (eine Zuweisung direkt im ViewBuilder kompiliert nicht). Kommentar warum: Look ist statisch und muss vor den Kindern stehen.
- `.id("\(palette.id)-\(palette.hell)")` statt `.id(zustand.daten.design)`, an NavigationStack und Sheet-Inhalt.
- `preferredColorScheme` an beiden Stellen aus `Designs.erzwingtHell(...)` (`nil` → `nil`, `true` → `.light`, `false` → `.dark`).

`GeschenkeApp.body` wird `WindowGroup { Wurzel().environmentObject(zustand) }`.

- [ ] **Step 3: Weichen für `.zuhause`**
- `DesignHintergrund`: `case .zuhause:` Lichtinsel `RadialGradient(colors: [Color(hex: 0xEFB249).opacity(Look.palette.hell ? 0.30 : 0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 420)`.
- `KartenView.rahmen`: `case .normal, .zuhause:`.

- [ ] **Step 4: Schalter in `EinstellungenView`**

Direkt nach dem Abschnitt „Design“, nur wenn `zustand.daten.design == Designs.zuhauseID`: `Section` „Erscheinung“ mit segmentiertem `Picker` über `Erscheinung.allCases` (Bindung wie bei der Schriftgröße, Setter `zustand.setzeErscheinung`), Fußzeile „Automatisch folgt dem Dunkelmodus des iPhones.“, `.listRowBackground(Look.karte)`.

- [ ] **Step 5: Bauen**

Code einmal auf Kompilierfehler durchlesen (exhaustive `switch` auf `DesignStil`: `grep -rn "switch Look.stil" ios/Geschenke`), dann:

```bash
git add ios/Geschenke && git commit -m "Follow system dark mode in Zuhause design with manual override"
git push origin design-neu
gh workflow run ios-build.yml --ref design-neu
gh run watch $(gh run list --workflow ios-build.yml --branch design-neu --limit 1 --json databaseId -q '.[0].databaseId') --exit-status
```

Erwartet: grün, Artefakt `Geschenke-ipa` vorhanden. Bei Rot: `gh run view --log-failed`, nur die `error:`-Zeilen beheben.

- [ ] **Step 6: Luka testet auf dem iPhone** (IPA aus dem Artefakt per SideStore)

Prüfliste für Luka:
1. Einstellungen → Design „Zuhause“ → Abschnitt „Erscheinung“ erscheint.
2. „Automatisch“ + Dunkelmodus im Kontrollzentrum umschalten → App wechselt ohne Neustart zwischen Abendlicht und Hell.
3. „Hell“ bei Dunkelmodus an → App bleibt hell. Danach „Automatisch“ → App wird sofort wieder dunkel (Review Focus 1).
4. Ein altes Design (z. B. Nachtblau) wählen → sieht aus wie vorher.

Hakt Punkt 3: Fallback aus Review Focus 1 umsetzen und Schritt 5 wiederholen.

---

### Task 4: Leiste und Startseite im Zuhause-Stil

Vorlage: `.superpowers/zeigen/ansichten/2026-11-04-coco-test-2/index.html` (Reiter „Nachher“, Spalten „Abendlicht · Linie Cognac“ und „Hell“). Nur bei `Look.stil == .zuhause`; alte Designs behalten `StartView` mit Kacheln.

**Files:**
- Create: `ios/Geschenke/ZuhauseTabs.swift`, `ios/Geschenke/ZuhauseStartView.swift`
- Modify: `ios/Geschenke/Wurzel.swift` (Weiche), `ios/Geschenke/StartView.swift` (nur: `ProfilKarte` und `genitiv` von `private` auf intern, damit die neuen Views sie nutzen)

**Interfaces:**
- Consumes: Bildnamen aus Task 2, `begruessung(stunde:)` aus Task 1, `Wurzel` aus Task 3, vorhandene Views `LaengeView`, `MerklisteView`, `ProfilView(profilID:)`, `SammelAuswahlView(vorauswahl:)`, `WischZielView(ziel:)`, `KartenBild`, `naechsterAnlass(heute:profile:)`
- Produces: `enum ZuhauseReiter: Hashable { case start, wischen, merkliste, profile }`; `struct ZuhauseTabs: View`; `struct ZuhauseStartView: View` mit `@Binding var reiter: ZuhauseReiter`

- [ ] **Step 1: Weiche in `Wurzel`** – `Look.stil == .zuhause` → `ZuhauseTabs()`, sonst wie bisher `NavigationStack { StartView() }`. `.id`, Sheet und Modifier bleiben außen.

- [ ] **Step 2: `ZuhauseTabs`** – System-`TabView(selection:)` (iOS 26 zeichnet sie mit Liquid Glass; das weicht bewusst von der flachen Leiste im Entwurf ab), jeder Reiter mit eigenem `NavigationStack`. SF Symbols (Bedienelemente, erlaubt nach DESIGN.md 4): Start `house`, Wischen `rectangle.stack`, Merkliste `heart`, Profile `person.2`.
  - **Wischen:** Liste „Für wen wischen?“ mit allen Profilen (Tippen → `WischZielView` für diese Person), darunter „Für mehrere“ → `SammelAuswahlView` (nur ab 2 Profilen) und „Neue Person“ → `LaengeView`. Ohne Profile: Hinweis „Noch keine Profile. Starte eine Suche, danach kannst du hier weiterwischen.“ mit Knopf zu `LaengeView`.
  - **Merkliste:** `MerklisteView()`.
  - **Profile:** alle Profile als `ProfilKarte` → `ProfilView`, Löschen per Kontextmenü wie in `StartView`; leer: derselbe Hinweistext wie bisher in `StartView`.

- [ ] **Step 3: `ZuhauseStartView`** (Reihenfolge und Maße wie in der Vorlage)
  1. **Kopf:** `begruessung(stunde: Calendar.current.component(.hour, from: Date()))` in `.largeTitle.bold()` (`.lineLimit(1).minimumScaleFactor(0.7)`), darunter „für wen suchst du heute?“ (`.subheadline`, `Look.leise`), Zahnrad rechts oben (öffnet die Einstellungen).
  2. **Hauptkarte** (Ecken 26, `Look.karte`, im Hellen 1 pt Rand `Look.rand`): „Geschenk finden“ (`.title2.bold()`), „Erzähl mir kurz von der Person, ich suche passende Ideen.“ (`.subheadline`, `Look.leise`), Kapsel „Gespräch starten“ (mindestens 44 pt hoch, `Look.aufAkzent` auf `Look.akzent`) → `LaengeView`. **Erkennungsmerkmal:** `coco-katze` (Breite 132) liegt rechts oben auf der Kartenkante (`.overlay(alignment: .topTrailing)` mit negativem Versatz nach oben, Platz darüber per `padding(.top)`).
  3. **Anlasszeile** (ohne Kasten): `coco-kranz` bei Weihnachten, `coco-stapel` bei Geburtstag (48 × 48), Text in zwei Zeilen: fett „noch N Tage“ / „morgen“ / „heute“, darunter `Look.leise` „bis Weihnachten“ bzw. „bis Mamas Geburtstag“ (`genitiv`), keine Emojis. Rechts „Für alle ›“ bzw. „Für Mama ›“ mit mindestens 44 pt Tippfläche → wie bisher `anlassGewaehlt` (Logik aus `StartView` übernehmen).
  4. **Zuletzt gemerkt** (Ecken 16): Zeile „Zuletzt gemerkt“ + „alle N ›“ (setzt `reiter = .merkliste`), darunter die ersten 3 Einträge der Merkliste als Quadrate: `KartenBild` auf Creme-Tafel (`palette-zuhause.md`: creme) mit `.blendMode(.multiply)`, Ecken 10, Preis darunter in `Look.preis`. Leer: „Noch nichts gemerkt. Was du beim Wischen nach rechts schiebst, landet hier.“
  5. **Profile:** keine Kacheln und keine Liste aller Profile (dafür gibt es den Reiter). Nur wenn Profile existieren: eine Zeile mit dem ersten Profil (`ProfilKarte` ohne Farbstreifen im Zuhause-Stil, Ecken 16) und „alle N ›“ → `reiter = .profile`.
  Kein ✨, keine Großbuchstaben-Überschriften, keine Kacheln.

- [ ] **Step 4: Bauen** wie Task 3, Schritt 5 (Commit-Message: `Add tab bar and Zuhause start screen`).

- [ ] **Step 5: Prüfen und zeigen** – Luka testet auf dem iPhone und schickt Bildschirmfotos: Start in Abendlicht und Hell, Start mit Schriftstufe „Sehr groß“, Reiter Wischen, Start ohne Profile und ohne Merkliste (frische Installation nicht nötig: Fotos von vorhandenem Stand reichen, leere Zustände per Profil löschen prüfen). Die Fotos legt Claude auf die Zeigeseite (Ansicht `2026-11-04-vorschau-iphone`) und lässt sie vom `design-pruefer` bewerten. Prüfen: Motive gefärbt (Review Focus 3), nichts abgeschnitten (Review Focus 4), leere Zustände (Review Focus 5), Nachtblau unverändert mit Kacheln.

- [ ] **Step 6: Abschluss**

Kein Merge. Fahrplan `docs/superpowers/plans/2026-11-03-design-neu.md`: in Phase 1 Illustrationspaket (Coco Material) und Hell/Dunkel (beides, Automatik + Schalter) abhaken, Vorschau-Einbau als Notiz vermerken. Obsidian-Übergabe mit dem Skill `obsidian-uebergabe`.
