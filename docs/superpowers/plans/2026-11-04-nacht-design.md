# Nacht 04./05.11. – Design „Zuhause“ flüssiger und schöner, dann in die App

> **For agentic workers:** Plan wird in derselben Session ohne Rückfragen abgearbeitet (Lukas Auftrag per /goal, 04.11. 21:55). Fortschritt unten in „Zeitplan und Stand“ abhaken.

**Goal:** Geschenk-Startanimation und Auspack-Animation der Wischkarte nach Lukas Änderungswünschen flüssiger und schöner machen, die übrigen Screens verbessern, alles vom `design-pruefer` freigeben lassen und anschließend so weit wie möglich in die echte App auf `design-neu` einbauen (IPA als Actions-Artefakt).

**Architecture:** Erst die HTML-Demos auf der Zeigeseite (dort kann der Prüfer Bewegung beurteilen), dann SwiftUI. Die Startanimation läuft in den Demos neu über eine Zeitfunktion `bild(t)` statt CSS-Transitions: flüssig, anhaltbar, und daraus werden für die App Einzelbilder gerendert und zu einem Video pro Farbwelt zusammengesetzt (exakt die freigegebene Animation, kein blinder 3D-Nachbau). Die Wischkarte wird in SwiftUI nativ gebaut (Ziehen, Papier, Türen, Licht sind 2D-Ebenen mit `rotation3DEffect`).

**Tech Stack:** HTML/CSS/JS (Demos), Playwright (Prüfen, Einzelbilder), Python + imageio-ffmpeg (Video), SwiftUI iOS 26, GeschenkeCore (CI unter Linux), GitHub Actions.

**Spec:** `DESIGN.md` (vor allem 5, 6, 6a, 6b), `docs/design/palette-zuhause.md`, `docs/superpowers/plans/2026-11-04-design-vorschau.md` (Tasks 1–3 gelten weiter, Task 4 wird hier ersetzt), freigegebene Demos `2026-11-04-coco-test-2`, `2026-11-04-startanimation`, `2026-11-04-wischkarte`.

## Lukas Vorgaben für diese Nacht (wörtlich zusammengefasst)

- Plan erstellen und ohne Fragen ausführen, fertig bis **05:55** (Start 21:55). Regelmäßig auf die Uhr schauen.
- Flüssiger und schöner. **Nichts, was nach KI aussieht**, außer dem Freigegebenen (Geschenk-Logo).
- Schwerpunkt Geschenk- und Auspackanimation, den Rest auch verbessern.
- **Geschenkanimation:** (1) In der Draufsicht wirkt das Geschenk zu dünn, es soll dicker sein. (2) Beim Reinzoomen soll das Geschenk nicht verschwinden, sondern bleiben, bis das Licht es verschwinden lässt: Gefühl, ins Geschenk hineinzufliegen.
- **Auspackanimation:** Proportionen stimmen nicht (der Knoten ist z. B. nicht in der Mitte). Der Lichtstreifen bleibt zu lange in der Mitte und schwebt später in der Luft.
- Antworten vor dem Start: erst Demos, dann App · Commit, Push und Build auf `design-neu` erlaubt (nie `main`) · offene Punkte wie die Schrift darf Claude entscheiden.

## Global Constraints

- Nur `design-neu`, kein Merge nach `main`. Grundbausteine 1–11 aus `CLAUDE.md` gelten (u. a. Provision nie in der Reihenfolge, Geheimnisse nie im Repo, kostenlos im Betrieb).
- Farben nur aus `docs/design/palette-zuhause.md`. Kein Blau, kein reines Weiß/Schwarz, kein Lila. Einziges Leuchten: Lichtinsel oben links, plus die Lichtmomente der beiden Animationen (6a/6b).
- Keine Emojis, keine Großbuchstaben-Überschriften, keine Kacheln, keine KI-SVGs außer dem Geschenk-Logo und seiner Verpackungssprache (Box, Band, Knoten, Anhänger).
- Routine-Bewegung ≤ 300 ms, nicht federnd. „Bewegung reduzieren“ = nur Überblenden. Tippflächen ≥ 44 pt. Kontrast ≥ 4,5.
- Jede Demo vor dem Anmelden durch den `design-pruefer` (höchstens 3 Runden, Freigabe bei allen Noten ≥ 7; Ziel diesmal 8).
- Swift nur in CI prüfbar: vor jedem Push gezielt auf Kompilierfehler lesen. Mac-Minuten sparen: App-Build nur bündeln, nicht nach jeder Kleinigkeit.
- Schriften nur mit OFL-Lizenz (dürfen in die App), Lizenzdatei mit ins Repo.

## Review Focus

1. **Farbsprung Video → App:** Das Startvideo endet in voller Lichtflut. Die native Flut danach muss exakt dieselbe Farbe haben, sonst blitzt es. Video in voller Farbtiefe kodieren, Übergang mit 150 ms Überblendung.
2. **Andere iPhone-Größen:** Video füllt per Aspect-Fill; Logo und Ring müssen auf 375–440 pt Breite mittig deckungsgleich bleiben.
3. **Server antwortet nie:** Ring bleibt nicht ewig stehen. Nach 25 s „zum Öffnen tippen“ trotzdem anbieten, die App zeigt ihre normalen Fehlermeldungen.
4. **Schnelles Wischen während des Auspackens:** zweiter Wurf, solange die Türen noch aufgehen, darf nichts doppelt zählen oder hängen bleiben (Eingabe sperren bis die neue Karte oben liegt, Auspacken dann sofort beenden).
5. **Lange Namen** auf dem Anhänger („für Oma Gertrud“) und große Schrift: umbrechen statt stauchen, nichts abgeschnitten.

---

## Phase A – Demos (Zeigeseite)

### A1: Startanimation v2 (`ansichten/2026-11-05-startanimation-2/`)

- Neuer Ablauf als Zeitfunktion `bild(t)` (t in s, 0 … 4,2) mit `requestAnimationFrame`, eigene Easing-Kurven (keine Federn). Schieberegler „Zeit“ zum Anhalten für Luka und den Prüfer.
- **Dicker:** Box höher (Seitenverhältnis Kante : Höhe ≈ 1 : 0,8 statt flach), Draufsicht nicht exakt 90°, sondern etwa 65–70° Neigung mit stärkerer Perspektive, damit Wände und Tiefe sichtbar bleiben. Innenwände dunkler nach unten, Boden leuchtet.
- **Hineinfliegen:** Die Kamera fährt in die Öffnung (Szene `translateZ` Richtung Betrachter), die Wände wachsen an den Bildrand und ziehen vorbei. Die Box wird **nicht** ausgeblendet. Das Licht vom Boden wächst, bis es den ganzen Bildschirm deckt; erst dann ist die Box weg. Danach zieht sich das Licht nach oben links zur Lichtinsel zusammen.
- Die Boxseite, die beim alten Zoom schräg zu sehen war, entfällt, weil die Kamera mittig über der Öffnung bleibt.
- Rest wie freigegeben (Katze auf dem Deckel, Ring creme, Tippen, Skip, Bewegung reduzieren).

### A2: Wischkarte v2 (`ansichten/2026-11-05-wischkarte-2/`)

- **Proportionen:** Band als ein Stück in der Kartenmitte (senkrecht exakt 50 %, waagerecht auf Höhe der Bildmitte), Knoten exakt auf dem Kreuz, Anhänger hängt am Knoten. Maße aus einer Stelle (CSS-Variablen), damit es auf jeder Kartengröße stimmt.
- **Licht ohne Schweben:** Das Licht liegt **zwischen Produkt und Türen** und ist nur durch den Spalt zu sehen. Wenn die Türen offen sind, klingt es in ≤ 250 ms auf dem Produkt aus. Kein Streifen mehr, der allein im Raum steht.
- Ablauf über eine Zeitfunktion (wie A1), Türen mit Perspektive, Knoten löst sich, Anhänger kippt weg. Untere Karte wächst beim Ziehen von 96 % auf 100 %.
- Anhänger: Name bricht ab ca. 12 Zeichen auf zwei Zeilen um, statt gestaucht zu werden. Lichtverlauf mit einem weichen Kern.

### A3: Übrige Screens und Schrift (`ansichten/2026-11-05-screens/`)

- Schriftvergleich (2–3 OFL-Kandidaten, warm und rund, nicht Inter/Poppins/Montserrat/DM Sans) auf Startseite und Wischkarte. Claude entscheidet nach Prüfer-Noten, Entscheidung in DESIGN.md 3 vermerken (änderbar durch Luka).
- Screens in Abendlicht und Hell: Startseite (Profile über Start erreichbar), Wischen-Auswahl („für wen?“), Merkliste, Einstellungen (Erscheinung, Zum Öffnen tippen, Auspacken langsam/normal/schnell/aus), Profil, leere Zustände.

### A4: Abschluss Phase A

- Alle drei Demos freigegeben und angemeldet. DESIGN.md (6a, 6b, 3) nachziehen. Commit der Doku.

## Phase B – App (`design-neu`)

### B1: Kern (Helfer-Agent, parallel zu Phase A)

Wie `2026-11-04-design-vorschau.md` Task 1 und 2, zusätzlich:
- `AppDaten.startTippen: Bool = true`, `AppDaten.auspacken: String = "normal"` (Werte `langsam|normal|schnell|aus`), beide mit `decodeIfPresent`.
- `public enum AuspackTempo: String, CaseIterable { case langsam, normal, schnell, aus }` mit `dauer: Double` (1,3 / 0,8 / 0,45 / 0) und `titel`.
- `public func richtigGuteTreffer(_ karten: [Karte], gewichtung: Gewichtung, anteil: Double = 0.1) -> Set<String>`: Punktzahl = Summe der Gewichte der Karten-Tags, die besten `anteil` (mindestens 1 Karte bei ≥ 5 Karten, nur Punktzahl > 0). Provision kommt nicht vor (Grundbaustein 4).
- `public func passtWeil(_ karte: Karte, gewichtung: Gewichtung) -> String?`: Label des Tags mit dem höchsten positiven Gewicht.
- Tests für alles, Push, Kern-CI grün.

### B2: Erscheinung, Leiste, Startseite (Task 3 + neue Task 4)

- Wurzel mit Erscheinung (Task 3 aus dem alten Plan).
- Leiste Start, Wischen, Merkliste, Einstellungen. Profile über die Startseite. Startseite nach freigegebener Demo, Schrift aus A3 eingebunden (`UIAppFonts`, `Font.custom(_:size:relativeTo:)`).

### B3: Wischkarte nativ

- Im Zuhause-Stil: `ZuhauseWischKarte` mit Verpackung, Grund-Chip (`passtWeil`), Textknöpfen „weiter“/„merken“, Auspacken für `richtigGuteTreffer` nach `AuspackTempo`, Bewegung reduzieren. Alte Designs unverändert.

### B4: Startbildschirm

- Einzelbilder aus A1 rendern (Playwright, 390 × 844 @3x, 60 fps) → `start-abend.mp4`, `start-hell.mp4` (H.264). App: Logo + Ring (füllt sich mit echtem Aufwecken des Servers), Tippen oder automatisch (Einstellung), Video, danach native Lichtflut zur Lichtinsel. Zweites Tippen springt ans Ende. Bewegung reduzieren: Überblenden.
- App-Icon aus dem Logo (1024 px PNG).

### B5: Bauen und Übergabe

- App-Build per `gh workflow run`, Fehler beheben bis grün. Übersichtsseite „Nacht-Ergebnis“ auf der Zeigeseite. DESIGN.md, Plan-Stand, Obsidian-Übergabe.

## Zeitplan und Stand

| Bis | Schritt | Stand |
|---|---|---|
| 22:20 | Plan, Helfer B1 starten | |
| 23:40 | A1 Startanimation v2 freigegeben | |
| 00:40 | A2 Wischkarte v2 freigegeben | |
| 01:40 | A3 Screens + Schrift freigegeben, A4 | |
| 02:30 | B2 Erscheinung, Leiste, Startseite | |
| 03:30 | B3 Wischkarte nativ | |
| 04:30 | B4 Startbildschirm, Video, Icon | |
| 05:30 | B5 grüner Build, Übergabe | |
| 05:55 | Ende spätestens | |

**Neustart 05.11. 00:01** nach Nutzungslimit (22:10–00:00 verloren). Neuer Zeitplan:
00:55 A1 · 01:40 A2 · 02:10 A3 (nur Schrift + Startseite/Einstellungen) · 03:10 B2 · 04:00 B3 · 04:45 B4 · 05:40 B5. Helfer B1 neu gestartet (bis 01:45).

**Stand 05.11. 00:40:**
- B1 fertig (Kern-CI grün, 81 Tests). B2 fertig (Leiste, Startseite, Erscheinung, Nunito).
- A1 freigegeben (Runde 2, alle 8/10), Feinschliff des Prüfers eingebaut, angemeldet.
- B4: Videos `start-abend.mp4`/`start-hell.mp4` (1170×2532, 60 fps, BT.709) und Standbilder in der App; Hell-Flut nativ auf #F6E7C8 korrigiert (vorher Farbsprung). App-Icon aus dem Logo.
- B3 nativ geschrieben (`ZuhauseWischView.swift`), auch nach dem Chat (vorher öffnete der Chat immer die alte Wischansicht). Merkliste, Knöpfe, Chips, Chat-Blasen im Zuhause-Stil.
- CI-Fehler gefunden: Der Bau-Schritt meldete grün, obwohl Swift nicht kompilierte (nur `.app`-Ordner geprüft). Jetzt wird die Programmdatei geprüft.
- A2 beim Prüfer (Runde 1). A3 danach.

**Stand 05.11. 05:15 (Ende der Nacht):**
- A3 Screens: Runde 2 ÜBERARBEITEN (8/8/7/7/8), Runde 3 FREIGEBEN (alle 8/10), angemeldet. Großschrift-Punkte nativ (Merkliste ohne Zeilenlimit ab xLarge, Motiv in den Einstellungen weicht ab xxLarge).
- B5: letzter grüner Build 41966183169 (1.0.26). Alle Entwürfe freigegeben, wartet auf iPhone-Test und Merge durch Luka.

**Stand 05.11. 05:05** (zweites Nutzungslimit ca. 01:05–05:00):
- A2 Wischkarte v2 freigegeben (Runde 2, alle 8/10), Feinschliff eingebaut, angemeldet; alle Punkte nativ übertragen (Geste am Stapel, Auspacken endet bei 0,66, Knoten/Anhänger, Hell-Creme).
- A3 Screens: Runde 1 ÜBERARBEITEN (7/7/6/6/6, Nunito bestätigt). Punkte in Entwurf und App umgesetzt, Runde 2 läuft. Nicht angemeldet, solange nicht freigegeben.
- B5: letzter grüner Build 41965289050 (1.0.25). Übersichtsseite `ansichten/2026-11-05-nacht-ergebnis/` angemeldet.

**Abgebrochen 04.11. ca. 22:10 (Nutzungslimit erreicht).** Stand damals:
- Plan steht. A1 begonnen: `.superpowers/zeigen/ansichten/2026-11-05-startanimation-2/` (erzeugen.py, vorlage.html, index.html gebaut, Zeitfunktion `bild(t)`, tiefere Box mit Kartonrand, Hineinfliegen, Export-Modus `?export=abend|hell`). Noch nicht angeschaut, nicht geprüft, nicht angemeldet. Kontaktbogen: `pruefung/bogen1.png`.
- B1-Helfer wurde angehalten, bevor er fertig war. Vor dem Weitermachen `git status` prüfen: Teiländerungen in `ios/` möglich, evtl. schon Commits/Push auf design-neu.
- Weiter mit: bogen1.png ansehen, A1 nachjustieren, Prüfer, dann A2.

Puffer-Regel: Liegt ein Schritt mehr als 30 min hinter dem Plan, wird der nächste verkleinert (zuerst A3-Umfang, dann B4-Icon), nie die Prüfung übersprungen.
