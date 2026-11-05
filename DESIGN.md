# DESIGN.md – Geschenke-App

Verbindliche Gestaltungsregeln für alle, die an der Oberfläche arbeiten (Menschen und
KI-Agenten). **Diese Datei hat Vorrang vor allgemeinen Design-Skills** wie
`swiftui-design-skill` oder `frontend-design`. Widerspricht ein Skill dieser Datei, gilt
diese Datei.

Stand 05.11.2026 · zuletzt umgesetzt: Runde 5 (`docs/superpowers/plans/2026-11-05-runde5.md`).
Was hier als **offen** markiert ist, ist noch nicht entschieden: nicht selbst festlegen,
sondern Luka fragen.

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
- „Zuhause“ ist das einzige Design der App (Luka, 05.11.2026: „alle anderen Designs entfernen
  und Zuhause das neue Standarddesign“). Eine Design-Auswahl gibt es nicht mehr.
- Braun vom Espresso bis zum Schaum, Akzent Kupfer `#C2721E`, Lampengelb als Licht,
  etwas Moosgrün. **Kein Blau, kein reines Weiß, kein reines Schwarz, kein Lila.**
- Eine Lichtinsel (weicher, warmer Verlauf oben links) ist das einzige erlaubte Leuchten.
  Sie steht für die Lampe im Raum. Sonst keine Verläufe, kein Glow, keine farbigen Schatten.
- Kontrast für Text mindestens 4,5 (`kontrast()` in `Designs.swift`, Tests im Kern).
- Kupfer als Schrift oder Symbol auf dem hellen Grund erreicht nur 2,97. In Hell steht
  Akzent-Schrift deshalb in Rotdunkel `#9A3A24` (`Look.akzentText`, auch der Tint der App);
  Kupfer bleibt dort Fläche (Knöpfe). Im Abendlicht ist Kupfer als Schrift erlaubt (4,8).

## 3. Schrift

- **Entschieden (Luka, 05.11.2026): Überschriften Fraunces, Text Nunito Sans** (beide OFL).
  Fraunces als weiche Serife (Achse SOFT 100, Bold), Nunito Sans für Fließtext, Knöpfe und
  Preise. Gewählt aus sechs Vorschlägen (Ansicht „Schriftvorschläge“): wirkt erwachsen, warm
  und nicht nach App-Baukasten. **Umgesetzt (Runde 5):** feste Schnitte `FrauncesSoft-Bold`
  und `NunitoSans-Regular/SemiBold/Bold/ExtraBold`, erzeugt mit
  `ios/werkzeuge/schriften/instanzen.py`. Fraunces (`Font.titel`) nur für Seitentitel,
  Abschnittsüberschriften, die Einführung und Navigationstitel; alles andere `Font.zuhause`.
  Im Code `Font.zuhause(stil, gewicht)` bzw. `Font.app(stil, gewicht)`.
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
  KI-gezeichneten SVGs. **Einzige Ausnahme:** das Geschenk-Logo (Abschnitt 6a), von Luka
  am 04.11. ausdrücklich so gewollt, weil es Einzelteile für die Animation braucht.
- Produktfotos aus dem Katalog sind unordentlich (weißer Hintergrund, Querformat). Jeder
  Entwurf mit Produktkarten wird mit echten Katalogfotos gezeigt.

## 5. Formen und Aufbau

- Keine Karte in Karte, kein Farbstreifen an einer Kartenseite, nicht Rand und Schatten
  zugleich.
- **Keine Kacheln** (Luka, 04.11.: „sehen zu sehr nach KI aus“). Navigation über die Leiste
  unten (Start, Wischen, Merkliste, Einstellungen), nicht über Kacheln auf der Startseite.
  Die Profile erreicht man über die Startseite (Luka, 04.11.).
- **Listen ohne Kachelflächen** (Luka, 05.11.: „die Kacheln weglassen“): „Zuletzt gemerkt“,
  „Deine Leute“, Merkliste, Profile, Einstellungen und Gewichtung stehen offen auf dem
  Hintergrund, getrennt durch Abstand und feine Linien (`offeneZeilen()`, `Look.trenner`).
  Eine Fläche behalten nur die Hauptkarte (die Katze schläft auf ihrer Kante) und die Wischkarte.
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

## 6a. Logo und Startbildschirm (Luka, 04.11.2026)

Demo: `.superpowers/zeigen/ansichten/2026-11-05-startanimation-2/` (v2, vom
`design-pruefer` freigegeben, alle Punkte 8/10). Vorgänger: `2026-11-04-startanimation/`.
In der App läuft sie als Video (`start-abend.mp4`, `start-hell.mp4`, gerendert aus der Demo,
60 fps, BT.709) bis zur vollen Lichtflut; das Zusammenziehen zur Lichtinsel ist nativ.

- **Logo = App-Icon:** creme Geschenkbox (Seiten schaum) mit rotem Band, auf dem Deckel
  schläft die Coco-Katze (kupfer). Linien 3,5 pt in der Linienfarbe, nur Palettenfarben.
  Die Variante mit Schleife ist verworfen (wirkt wie das 🎁-Emoji).
- **Startbildschirm:** das Logo groß in der Mitte, darum ein dünner Ring in creme, der sich
  füllt, während der Server aufwacht (echtes Laden, keine Deko). Darunter „einen Moment …“,
  dann „zum Öffnen tippen“. Lichtinsel oben links wie auf der Startseite, kein Schein
  hinter dem Geschenk.
- **Tippen** ist Standard. In den Einstellungen abschaltbar, dann öffnet sich das Geschenk
  von selbst, sobald der Ring voll ist.
- **Animation (ca. 4 s, einmaliger Moment, deshalb nicht an die 300 ms gebunden):** Deckel
  mit Katze hebt sich, warmes Licht kommt aus der Box, Kamera in die Draufsicht, Deckel
  blendet aus, man taucht ins Licht, das Licht zieht sich nach oben links zur Lichtinsel
  der Startseite zusammen. Zweites Tippen überspringt. „Bewegung reduzieren“: nur
  Überblenden.
- **Lukas Änderungen für v2 (04.11.):** In der Draufsicht wirkt das Geschenk dick (tiefe
  Box, 10 pt Kartonrand). Beim Hineinzoomen bleibt das Geschenk sichtbar, bis das Licht es
  auflöst, man fliegt also ins Geschenk hinein.
- **Offen:** vereinfachte Icon-Fassung für kleine Größen.

## 6b. Wischkarte (Luka, 04.11.2026)

Demo: `.superpowers/zeigen/ansichten/2026-11-05-wischkarte-2/`, in der App
`ZuhauseWischView.swift`.

Gefühl: Es soll aufregend sein, die nächste Karte zu sehen, und alles fließt, nichts wirkt starr.

- **Alle Karten:** Die Karte darunter trägt eine Geschenk-Optik (Papier und Band in
  Palettenfarben). Je weiter die obere Karte zur Seite gezogen wird, desto mehr verschwindet
  die Verpackung. Beim Loslassen liegt die neue Karte offen da.
- **Richtig gute Treffer** (zum Ausprobieren, später änderbar): bleiben verpackt, bis die
  obere Karte weg ist, dann packen sie sich richtig aus, mit Licht wie beim Startbildschirm.
  „Richtig gut“ heißt: passt laut Stichwörtern besonders gut zur Person (Vorschlag: beste
  10 %). Die Provision spielt keine Rolle (Grundbaustein 4).
- **Einstellungen:** Auspack-Geschwindigkeit langsam / normal / schnell / aus. „Aus“: Auch
  gute Treffer verlieren ihre Verpackung nur mit dem Wischen.
- **Flüssig:** Die Karte klebt am Finger, kippt leicht mit, fliegt beim Loslassen mit dem
  Schwung weiter. Nichts springt oder ruckelt. „Bewegung reduzieren“: Überblenden.
- **So gebaut (05.11., Lukas Änderungen):** Zwei Papierhälften mit rotem Band, Knoten
  genau auf der Bandkreuzung (alles an Bandbreite und Höhe aufgehängt, symmetrisch),
  Anhänger „für Name“ hängt darunter. Auspacken: Knoten löst sich, Anhänger fällt nach
  unten weg, die Hälften klappen nach hinten auf. Das Licht liegt zwischen Produkt und
  Papier, ist nur durch den Spalt zu sehen und ist weg, bevor das Papier verschwindet
  (kein schwebender Lichtstreifen). Die verpackte Karte schaut in Ruhe ein Stück unter
  der oberen hervor.
- **Schnelles Weiterwischen:** Ziehen oder Tippen während Flug oder Auspacken bringt
  beides sofort zu Ende und nimmt die nächste Karte. Kein Wisch geht verloren.

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

- Name, 3–5 Stichwörter für die Welt. Das Logo steht (6a), die Schrift ist umgesetzt (3),
  die alten Designs sind entfernt (2).
