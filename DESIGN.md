# DESIGN.md – Geschenke-App

Verbindliche Gestaltungsregeln für alle, die an der Oberfläche arbeiten (Menschen und
KI-Agenten). **Diese Datei hat Vorrang vor allgemeinen Design-Skills** wie
`swiftui-design-skill` oder `frontend-design`. Widerspricht ein Skill dieser Datei, gilt
diese Datei.

Stand 04.11.2026 · Fahrplan: `docs/superpowers/plans/2026-11-03-design-neu.md`
(Phase 1 läuft). Was hier als **offen** markiert ist, ist noch nicht entschieden: nicht
selbst festlegen, sondern Luka fragen.

## 1. Gefühl und Welt

- Lukas Wortlaut: „wie die Umarmung welche man beim Geschenk geben bekommt. ein Gefühl
  von Geborgenheit, Sicherheit und Vertrauen“
- Moodboard: „Zuhause, ruhige Farben, Couch, heißer Kakao“ (`docs/design/moodboard.md`)
- **Eigene Welt:** ein gemütliches Zuhause am Abend, in dem Geschenke gesammelt werden.
  Vorbilder mit eigener Welt: Forest, Waterllama, How We Feel, stoic.
- Verspielt und lebendig statt edel. Warm, nie kühl glänzend.

## 2. Farben

Einzige Quelle für alle Werte: `docs/design/palette-zuhause.md` (Abendlicht und Hell,
Oberfläche und Illustrationsfarben). Werte nie frei erfinden.

- Zwei Farbwelten: **Abendlicht** (dunkel, Standard am Abend) und **Hell**. Wechsel
  automatisch nach dem iPhone-Dunkelmodus, dazu ein Schalter in den Einstellungen.
- Braun vom Espresso bis zum Schaum, Akzent Kupfer `#C2721E`, Lampengelb als Licht,
  etwas Moosgrün. **Kein Blau, kein reines Weiß, kein reines Schwarz, kein Lila.**
- Eine Lichtinsel (weicher, warmer Verlauf oben links) ist das einzige erlaubte Leuchten.
  Sie steht für die Lampe im Raum. Sonst keine Verläufe, kein Glow, keine farbigen Schatten.
- Kontrast für Text mindestens 4,5 (`kontrast()` in `Designs.swift`, Tests im Kern).

## 3. Schrift

- **Offen:** Schriftwahl (Phase 2 im Fahrplan). Bis dahin Systemschrift.
- Immer Textstile (`.headline`, `.body` …), keine festen Größen: Dynamic Type muss gehen.
- Freundliche, kleingeschriebene Begrüßung („guten abend.“) wie bei stoic.
- **Keine** kleinen Großbuchstaben mit weitem Abstand über Überschriften („PROFILE“).
- Überschriften nicht automatisch in Serifenschrift (anders als im swiftui-design-skill).
- Lange deutsche Wörter („Weihnachtsgeschenk“, „Oma Gertrud“) dürfen nicht abgeschnitten
  werden, auch nicht bei Schriftstufe „Sehr groß“.

## 4. Bilder und Symbole

- **Illustrationen:** Coco Material (cocomaterial.com, CC0), eingefärbt mit der Palette.
  Erzeuger und Regeln: `docs/design/palette-zuhause.md`, ab dem Einbau
  `ios/werkzeuge/coco/`. (Anders als im swiftui-design-skill: Wir nehmen Illustrationen,
  keine Fotos und keine grauen Platzhalter.)
- Beim Einfärben gilt: ein Gegenstand bekommt eine Farbe, Lücken zeigen die Kartenfarbe,
  keine ungefärbten Reste.
- **Keine Emojis** als Symbole (✨ 🎁 ♥ 🎄 🎂). Gezeichnete Gegenstände statt Emojis.
- SF Symbols nur für reine Bedienelemente (Zahnrad, Pfeil, Papierkorb).
- Keine bekannten Gratis-Pakete wie unDraw, Humaaans oder Open Peeps. Keine
  KI-gezeichneten SVGs.
- Produktfotos aus dem Katalog sind unordentlich (weißer Hintergrund, Querformat). Jeder
  Entwurf mit Produktkarten wird mit echten Katalogfotos gezeigt.

## 5. Formen und Aufbau

- Keine Karte in Karte, kein Farbstreifen an einer Kartenseite, nicht Rand und Schatten
  zugleich.
- **Keine Kacheln** (Luka, 04.11.: „sehen zu sehr nach KI aus“). Navigation über die Leiste
  unten (Start, Wischen, Merkliste, Profile), nicht über Kacheln auf der Startseite.
- Kein gleichförmiges Kachelraster aus Symbol, Titel und Untertitel. Die Wichtigkeit
  bestimmt die Größe: eine große Hauptkarte, kleinere Nebenkarten.
- Eckenradius passend zur Größe (große Karte runder als ein kleiner Knopf).
- Pro Screen **ein** Erkennungsmerkmal, das mit voller Sorgfalt gemacht ist. Startseite:
  die Katze schläft auf der Kante der Hauptkarte (Coco-Test 2, von Luka als deutlich
  besser bewertet). Weitere Motive nur klein und mit Bedeutung (Kranz am Anlass, Tee beim Profil).
- Katalogfotos (weißer Grund) auf einer Creme-Tafel mit Multiplizieren zeigen, damit kein
  reines Weiß entsteht.
- Leere Zustände (keine Profile, Merkliste leer, Server wacht auf) gehören zum Entwurf.
- Tippflächen mindestens 44 × 44 pt.

## 6. Bewegung

- Routine-Animationen höchstens 300 ms, keine federnden oder elastischen Bewegungen
  (anders als im swiftui-design-skill).
- Keine Dauer-Animationen und kein Pulsieren ohne Anlass.
- „Bewegung reduzieren“ in iOS respektieren: dann nur Überblenden.
- Vibration nur bei Entscheidungen (Wischen, Merken).

## 7. Text

- Konkret statt Werbesprüche. Keine Gedankenstriche als Satzzeichen, Punkt statt Strich.
- Umlaute immer korrekt.

## 8. Prüfen, bevor Luka etwas sieht

1. Jeder Entwurf läuft durch die KI-Look-Prüfliste `docs/design/ki-look-checkliste.md`.
   Ein Treffer braucht einen Grund, der aus dem Moodboard kommt.
2. Der Agent `design-pruefer` (`.claude/agents/design-pruefer.md`) bewertet das
   Bildschirmfoto in 5 Punkten. Freigabe erst, wenn jeder Punkt mindestens 7/10 hat,
   höchstens 3 Überarbeitungsrunden.
3. App-Screens prüft Luka auf dem iPhone (kein Simulator ohne Mac).

## 9. Offen (Luka entscheidet)

- Schrift (Phase 2), Name und Marke, 3–5 Stichwörter für die Welt (Phase 1)
- Ob die 8 alten Designs bleiben, wenn „Zuhause“ fertig ist (Phase 3)
