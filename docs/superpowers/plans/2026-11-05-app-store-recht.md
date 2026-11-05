# App Store: Recht und Sicherheit – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die App erfüllt alles, was Apple und deutsches/EU-Recht für den Store-Start verlangen und was Claude allein bauen kann, und der Server ist gegen Missbrauch gehärtet.

**Architecture:** Rechtstexte liegen einmal als JSON (`rechtliches/rechtliches.json`); der Server rendert sie als Webseiten, die App bündelt dieselbe Datei und zeigt sie offline. Der Server bekommt Längen- und Größengrenzen, eine Drosselung je Verbindung und Sicherheits-Header. Die App fragt vor dem ersten KI-Kontakt nach Zustimmung, kennzeichnet Partnerlinks als „Anzeige“ und erklärt die Reihenfolge.

**Tech Stack:** FastAPI/pydantic (Python 3.12+), SwiftUI + GeschenkeCore (Swift 5, Tests auf Linux in CI), XcodeGen, GitHub Actions.

**Spec:** `docs/app-store/recherche.md`

## Global Constraints

- Grundbausteine in `CLAUDE.md` gelten; keiner darf aufgeweicht werden (besonders 9 Geheimnisse, 10 Datensparsam, 11 kostenlos).
- Texte deutsch, du-Form, Umlaute korrekt, keine Gedankenstriche als Satzzeichen (DESIGN.md 7).
- Oberfläche nur mit vorhandenen Bausteinen: `Look`, `Font.zuhause`, `Font.titel`, `Abzeichen`, `GoldKnopf`, `RandKnopf`, `offeneZeilen()`, `zuhauseHintergrund()`. Keine Emojis, SF Symbols nur für Bedienelemente.
- Swift nur per Edit/Write schreiben, nie per Bash-Heredoc (`\n`-Falle).
- Swift-Dateien im Repo sind LF.
- Kein lokaler Swift-Compiler: Kern-Tests und App-Build laufen in CI (`ios-core-tests.yml`, `ios-build.yml` per `gh workflow run ... --ref app-store-recht -f runner=macos-15`).
- Platzhalter für Lukas Angaben haben die Form `[...]` (Wert beginnt mit `[` und endet mit `]`).
- Bestehende Clients dürfen nicht brechen: zu lange Texte und Listen werden gekürzt, nicht abgelehnt.

## Review Focus

1. Sehr lange Gesehen-Liste (Profil nach Monaten Wischen, > 10 000 IDs) → Anfrage klappt weiter, Server nimmt die letzten 10 000.
2. Nutzer fügt einen sehr langen Text in den Chat ein (> 2000 Zeichen) → kein 422, Text wird gekürzt.
3. Zustimmung widerrufen, dann gespeichertes Profil öffnen und wischen → es geht keine Anfrage raus, stattdessen Zustimmungs-Bildschirm.
4. Bestandsnutzer mit alten `appdaten.json` ohne neue Felder → Daten bleiben erhalten, Zustimmung gilt als nicht gegeben.
5. Viele schnelle Anfragen hinter Cloudflare (gleiche Render-IP für alle) → Drosselung nach `cf-connecting-ip`, nicht nach Proxy-IP; sonst sperrt ein Nutzer alle.

---

### Task 1: Server-Grenzen, Header, Logs

**Files:**
- Modify: `app/modelle.py`, `app/main.py`, `app/ki.py`
- Test: `tests/test_sicherheit.py`

**Interfaces:**
- Produces: `modelle.MAX_TEXT = 2000`, `modelle.MAX_GESEHEN = 10_000`, `main.MAX_ANFRAGE_BYTES = 4_000_000`

- [ ] **Step 1: Failing tests** in `tests/test_sicherheit.py`:
  - `test_langer_chattext_wird_gekuerzt`: `ChatNachricht(rolle="nutzer", text="a"*5000).text == "a"*2000`
  - `test_lange_anweisung_wird_gekuerzt`: `ProfilAendernAnfrage(profil=..., anweisung="b"*5000).anweisung` hat Länge 2000
  - `test_gesehen_behaelt_die_letzten`: `KartenAnfrage(profil=p, gesehen=[str(i) for i in range(12_000)]).gesehen[0] == "2000"` und Länge 10 000; dasselbe für `SammelPerson`
  - `test_zu_viele_nachrichten_abgelehnt`: POST `/chat/naechste` mit 61 Nachrichten → 422
  - `test_zu_grosse_anfrage`: POST mit `Content-Length: 4000001` → 413
  - `test_post_ohne_laenge`: POST ohne Content-Length (Body per Generator) → 411
  - `test_docs_aus`: GET `/docs`, `/redoc`, `/openapi.json` → 404
  - `test_sicherheits_header`: GET `/health` hat `x-content-type-options: nosniff`, `referrer-policy: no-referrer`, `x-frame-options: DENY`, `strict-transport-security`
  - `test_log_ohne_ki_text` (in `tests/test_ki.py`-Stil mit Fake-Transport): kaputtes JSON mit Inhalt „Oma mag Rosen“ → Log enthält „Oma“ nicht
- [ ] **Step 2: Run** `.venv/Scripts/python -m pytest tests/test_sicherheit.py -q` → FAIL
- [ ] **Step 3: Implement**
  - `modelle.py`: `field_validator(mode="before")` kürzt `ChatNachricht.text`, `ProfilAendernAnfrage.anweisung`, `Profil.zusammenfassung` auf `MAX_TEXT`; `gesehen` in `KartenAnfrage` und `SammelPerson` auf die letzten `MAX_GESEHEN`; `ChatAnfrage.nachrichten` und `ProfilAusGespraechAnfrage.nachrichten` `Field(max_length=60)`; `SammelPerson.id` `Field(max_length=100)`.
  - `main.py`: `FastAPI(..., docs_url=None, redoc_url=None, openapi_url=None)`; HTTP-Middleware: bei POST ohne `content-length` → 411, über `MAX_ANFRAGE_BYTES` → 413 (JSON `{"fehler": ...}`); setzt die vier Header auf jede Antwort, bei `text/html` zusätzlich `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`.
  - `ki.py`: bei kaputtem JSON nur Modell und Länge loggen; bei unerwartetem Status nur Status und `error.code` (falls lesbar).
- [ ] **Step 4: Run** alle Tests → PASS (205 + neue)
- [ ] **Step 5: Commit** `Limit request sizes, add security headers, keep user text out of logs`

### Task 2: Drosselung je Verbindung

**Files:**
- Create: `app/drossel.py`
- Modify: `app/main.py`, `app/config.py`, `tests/conftest.py`
- Test: `tests/test_drossel.py`

**Interfaces:**
- Produces: `class Drossel(pro_minute: int, pro_tag: int, max_schluessel: int = 50_000, uhr: Callable[[], float] = time.time)` mit `erlaubt(schluessel: str) -> bool` und `zuruecksetzen() -> None`; `schluessel_fuer(request: Request) -> str` (Hash aus `cf-connecting-ip` → `true-client-ip` → `request.client.host`, Salz je Prozess); `main.DROSSEL`; Settings `drossel_pro_minute: int = 30`, `drossel_pro_tag: int = 1000`.

- [ ] **Step 1: Failing tests:** `test_minute_grenze` (3/min: 3× True, 4. False, nach 60 s wieder True), `test_tag_grenze`, `test_schluessel_getrennt`, `test_speicher_begrenzt` (max_schluessel=10, 20 Schlüssel → `len(intern) <= 10`), `test_cf_ip_vor_proxy_ip` (zwei Requests mit gleicher client-Adresse, verschiedenem `cf-connecting-ip` → verschiedene Schlüssel), `test_kein_klartext_ip` (Schlüssel enthält „203.0.113.5“ nicht), `test_route_429` (Settings-Grenze 2/min über `DROSSEL` ersetzt: 3. POST `/chat/naechste` → 429).
- [ ] **Step 2: Run** → FAIL
- [ ] **Step 3: Implement** feste Fenster je Schlüssel (Minute `int(t//60)`, Tag `int(t//86400)`); beim Überlauf erst alte Tage entfernen, dann notfalls alles leeren (lieber offen als falsch sperren). Dependency `drosseln(request)` auf alle fünf geschützten Routen (nach `pruefe_token`), 429 mit `{"detail": "zu_viele_anfragen"}`. Autouse-Fixture in `conftest.py` ruft `DROSSEL.zuruecksetzen()`.
- [ ] **Step 4: Run** alle Tests → PASS
- [ ] **Step 5: Commit** `Throttle AI routes per connection with hashed keys`

### Task 3: Partnerlinks als „Anzeige“

**Files:**
- Create: `app/partnerlinks.py`
- Modify: `app/modelle.py` (`Karte.anzeige: bool = False`), `app/karten.py`, `app/ideen.py`
- Test: `tests/test_partnerlinks.py`

**Interfaces:**
- Produces: `ist_partnerlink(link: str) -> bool`; Feld `anzeige` in jeder Karte der API.

- [ ] **Step 1: Failing tests:** True für `https://www.awin1.com/cread.php?...`, `https://clk.tradedoubler.com/click?...`, `https://www.amazon.de/s?k=x&tag=luka-21`, `https://amzn.to/abc`; False für `https://www.grillfuerst.de/p/1`, `https://www.amazon.de/s?k=x`, `https://evil-awin1.com/x`, `""`, `"kaputt"`. Karten-Test: Produkt mit Awin-Link → Karte `anzeige is True`, normaler Shop-Link → False; Ideenkarte mit gesetztem `amazon_tag` → True.
- [ ] **Step 2: Run** → FAIL
- [ ] **Step 3: Implement** Hosts `awin1.com, tradedoubler.com, webgains.com, adcell.com, belboon.de, financeads.net, tradetracker.net, prf.hn, amzn.to` (exakt oder Subdomain); Amazon-Hosts nur mit Query `tag`.
- [ ] **Step 4: Run** alle Tests → PASS
- [ ] **Step 5: Commit** `Mark partner links as ads on cards`

### Task 4: Rechtstexte als Webseiten

**Files:**
- Create: `rechtliches/rechtliches.json`, `app/rechtliches.py`, `scripts/pruefe_store_bereit.py`
- Modify: `app/main.py` (Router einbinden)
- Test: `tests/test_rechtliches.py`

**Interfaces:**
- Produces: JSON-Schema `{"stand": str, "angaben": {name, strasse, plz_ort, email, telefon: str}, "dokumente": [{"id", "titel", "abschnitte": [{"ueberschrift": str|null, "absaetze": [str]}]}]}`; Dokument-IDs `impressum, datenschutz, nutzung, support, lizenzen`; Absatz mit Präfix `- ` = Listenpunkt; Inline nur `**fett**` und `[Text](https|mailto-URL)`; Platzhalter `{{schluessel}}` aus `angaben` plus `{{stand}}`.
- Python: `lade_texte(pfad: Path = PFAD) -> dict`, `ausfuellen(text: str, texte: dict) -> str`, `inline_html(text: str) -> str`, `seite(dokument_id: str, texte: dict | None = None) -> str | None`, `offene_angaben(texte: dict) -> list[str]`, `router`.

- [ ] **Step 1: Failing tests:** jede der fünf Routen → 200, `text/html`, enthält den Titel und keine `{{`; `/datenschutz` nennt „Groq“, „Render“, „Art. 6“, „widerrufen“; `/impressum` enthält „§ 5 DDG“; `inline_html("<b>")` escaped; Link `[x](javascript:alert(1))` wird kein `<a>`; `[Mail](mailto:a@b.de)` wird `<a href="mailto:a@b.de">`; `offene_angaben` meldet alle fünf Platzhalter; jedes Dokument hat ≥ 1 Abschnitt; HTML-Seite hat CSP-Header; Routen brauchen keinen Token.
- [ ] **Step 2: Run** → FAIL
- [ ] **Step 3: Implement** Texte nach Spec (Abschnitte siehe `recherche.md`, Inhalt: Impressum § 5 DDG mit Streitbeilegungs-Satz; Datenschutz mit Verantwortlichem, Daten auf dem iPhone, Daten an Server, Groq, Render, Drosselung, Shop-Fotos/Links, Apple, kein Tracking, Rechtsgrundlagen, Bitte ohne sensible Angaben, Speicherdauer, Rechte inkl. Widerruf und Beschwerde LDI NRW, Art. 22, Stand; Nutzung mit Reihenfolge-Kriterien, Anzeige/Provision, Ideenkarten, Preise inkl. MwSt. ggf. zzgl. Versand, KI kann irren, Verfügbarkeit, Apple-EULA; Support; Lizenzen Fraunces/Nunito Sans OFL, Coco Material CC0, Pixabay). Seite mit kleinem Inline-CSS in Palettenfarben (Creme `#F7EBDD`-Ton aus `palette-zuhause.md`). Skript gibt offene Angaben und fehlende Store-Dateien aus, Exit-Code 1 solange etwas offen ist.
- [ ] **Step 4: Run** alle Tests → PASS
- [ ] **Step 5: Commit** `Add legal texts as one JSON, served as web pages`

### Task 5: Swift-Kern

**Files:**
- Create: `ios/GeschenkeCore/Sources/GeschenkeCore/Rechtstexte.swift`, `ios/GeschenkeCore/Tests/GeschenkeCoreTests/RechtTests.swift`
- Modify: `AppDaten.swift` (`kiEinwilligung`), `Modelle.swift` (`Karte.anzeige`), `AppDaten.swift` (`AppDatenSpeicher.loescheAlles()`)

**Interfaces:**
- Produces: `Rechtstexte: Decodable` mit `stand`, `angaben: [String: String]`, `dokumente: [Rechtsdokument]`, `func dokument(_ id: String) -> Rechtsdokument?` (Platzhalter ersetzt), `var offeneAngaben: [String]`, `static func laden(_ daten: Data) throws -> Rechtstexte`; `Rechtsdokument: Decodable, Identifiable { id, titel, abschnitte: [Rechtsabschnitt] }`; `Rechtsabschnitt { ueberschrift: String?, absaetze: [String] }`; `AppDaten.kiEinwilligung: Int` (0 = nein), `AppDaten.kiEinwilligungVersion = 1`, `AppDaten.hatKiEinwilligung: Bool`; `Karte.anzeige: Bool?`, `Karte.istAnzeige: Bool`, `Karte.sichererLink: URL?` (nur `https`/`http` mit Host); `AppDatenSpeicher.loescheAlles() throws` (löscht `appdaten.json` und `appdaten.kaputt-*.json` im selben Ordner).

- [ ] **Step 1: Failing tests:** echte Datei über `#filePath` → fünf Dokumente, kein `{{` im Impressum nach `dokument("impressum")`; `offeneAngaben` nicht leer; alte AppDaten-JSON ohne `kiEinwilligung` → `hatKiEinwilligung == false`, Profile erhalten; Rundreise mit `kiEinwilligung = 1` → true; Karte-JSON ohne `anzeige` → `istAnzeige == false`; `sichererLink` nil für `javascript:alert(1)`, `tel:123`, `""`, gesetzt für `https://x.de/p`; `loescheAlles` entfernt Hauptdatei und eine `appdaten.kaputt-1.json`, lässt `andere.json` stehen.
- [ ] **Step 2: Push** Zweig, `ios-core-tests.yml` → FAIL (oder vorher kompilierfehlerfrei rot)
- [ ] **Step 3: Implement** wie Interfaces.
- [ ] **Step 4: CI** `ios-core-tests.yml` → grün
- [ ] **Step 5: Commit** `Core: legal texts, AI consent flag, ad flag, safe links, delete all`

### Task 6: App-Oberfläche

**Files:**
- Create: `ios/Geschenke/KiEinwilligungView.swift` (Bildschirm + `View.brauchtKiEinwilligung()`), `ios/Geschenke/RechtstextView.swift`
- Modify: `AppZustand.swift` (`setzeKiEinwilligung(_:)`, `loescheAlles()`, `static let rechtstexte`), `EinstellungenView.swift`, `LaengeView.swift`, `WischZiel.swift`, `ProfilView.swift`, `ChatView.swift`, `ZuhauseWischView.swift`, `MerklisteView.swift`, `URLSessionTransport.swift`

**Interfaces:**
- Consumes: Task 5.
- Produces: `struct KiEinwilligungView(fertig: (Bool) -> Void)`; `extension View { func brauchtKiEinwilligung() -> some View }` zeigt statt des Inhalts den Bildschirm, bis zugestimmt ist; „Nicht jetzt“ ruft `dismiss()`; `struct RechtstextView(dokumentID: String)`.

- [ ] **Step 1:** Tor auf `LaengeView` und `WischZielView`; in `ProfilView` ist das Änderungsfeld ohne Zustimmung gesperrt und zeigt „Für Änderungen per Chat brauche ich deine Zustimmung.“ mit Knopf, der `KiEinwilligungView` als Sheet öffnet.
- [ ] **Step 2:** Einstellungen: Abschnitt „Datenschutz und Rechtliches“ mit Zeilen Impressum, Datenschutzerklärung, So entstehen die Vorschläge, Lizenzen (NavigationLink → `RechtstextView`), Zustimmung geben/widerrufen (Widerruf mit Rückfrage), „Alle Daten löschen“ (destruktiv, Rückfrage). Token-Feld nur, wenn kein Token im Build steckt.
- [ ] **Step 3:** Karte: `Abzeichen("Anzeige")` oben rechts auf dem Foto, wenn `istAnzeige`; Merkliste-Zeile „Anzeige“ neben dem Shop; Info-Knopf `info.circle` in der Wisch-Leiste → Sheet `RechtstextView("nutzung")`; Chat beginnt mit Hinweis „Du schreibst mit einer KI. Sie kann sich irren.“; Links nur über `sichererLink`; Fehlertext für 429: „Gerade kommen sehr viele Anfragen. Warte eine Minute und versuch es dann nochmal.“
- [ ] **Step 4:** `gh workflow run ios-build.yml --ref app-store-recht -f runner=macos-15` → „BUILD SUCCEEDED“
- [ ] **Step 5: Commit** `App: AI consent, legal screens, ad badge, ranking info, delete all`

### Task 7: Store-Technik und CI

**Files:**
- Create: `ios/Geschenke/PrivacyInfo.xcprivacy`, `.github/workflows/wachhalten.yml`
- Modify: `ios/project.yml`, `.github/workflows/ios-build.yml`, `.github/workflows/server-tests.yml`

- [ ] **Step 1:** Manifest: `NSPrivacyTracking false`, `NSPrivacyTrackingDomains []`, `NSPrivacyCollectedDataTypes` = Other User Content (nicht verknüpft, kein Tracking, Zweck App Functionality), `NSPrivacyAccessedAPITypes` = UserDefaults `CA92.1`.
- [ ] **Step 2:** `project.yml`: `ITSAppUsesNonExemptEncryption: false`; `../rechtliches/rechtliches.json` als Ressource. `ios-build.yml`: Pfad `rechtliches/**`, nach dem Bauen `test -f` für `PrivacyInfo.xcprivacy` und `rechtliches.json` im `.app`.
- [ ] **Step 3:** `wachhalten.yml`: `workflow_dispatch` mit `stunden` (1–6, Standard 6), ruft alle 10 min `/health`. `server-tests.yml`: Schritt `pip-audit -r requirements.txt`, Pfad `rechtliches/**`.
- [ ] **Step 4:** CI-Läufe grün (Build mit den neuen `test -f`).
- [ ] **Step 5: Commit** `Add privacy manifest, export flag, keep-awake workflow, dependency audit`

### Task 8: Checkliste, Review, Merge

**Files:**
- Create: `docs/app-store/checkliste.md`
- Modify: Vault `Projekte/geschenke-app.md`, `INDEX.md`

- [ ] **Step 1:** Checkliste für Luka: Entwicklerkonto, Gewerbe, Angaben eintragen, Groq ZDR, DSA-Status, App-Privacy-Antworten, Altersfreigabe, Verschlüsselung, Prüfer-Notiz, Wachhalten, Name, Signieren ohne Mac, Partnerprogramme und Bildrechte.
- [ ] **Step 2:** Schluss-Review (Opus) über den Zweig, Befunde beheben.
- [ ] **Step 3:** Merge nach `main` (Luka hat Merge erlaubt), Render-Deploy und Routen live prüfen, Release-Build prüfen.
- [ ] **Step 4:** Vault-Übergabe (`obsidian-uebergabe`).
