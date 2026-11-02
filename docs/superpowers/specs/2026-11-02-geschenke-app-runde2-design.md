# Geschenke-App – Runde 2: Design

Stand: 02.11.2026 · baut auf `2026-11-02-geschenke-app-design.md` (v1) auf · Branch `app/runde2`

## Warum

Luka hat v1 gesehen und will die App alltagstauglicher machen: Weihnachten für
viele Leute auf einmal, weniger Ärger beim Wischen (Vertippen, Wiederholungen,
wackelnde Bilder) und mehr Persönlichkeit durch wählbare Designs.

## Ziele (Lukas 10 Punkte)

1. **Wählbare Designs** in den Einstellungen.
2. **Sammelsuche:** mehrere Profile zusammen wischen, jede Karte sagt, für wen.
3. **Einheitliche Bilder:** jedes Bild gleich groß und gleich geschnitten.
4. **Merkliste aus der Wisch-Ansicht** per Knopf erreichbar.
5. **Genaue Preise** (siehe unten – nur teilweise möglich).
6. **Merkliste mit Bildern** statt Emojis.
7. **Budget als eigene Frage** mit Regler und Spanne (von–bis).
8. **Schon Gesehenes nicht wiederholen**, auch nach versehentlichem Verlassen.
9. **Rückgängig-Knopf** für Verwischer.
10. **Offene Kleinpunkte aus der v1-Prüfung** beheben.

## Nicht-Ziele

- Keine Amazon-Produkt-API (gibt es erst nach 3 Verkäufen) → Ideenkarten bleiben bei Preisspannen.
- Keine gespeicherten Gruppen („Weihnachten“ als festes Profil) – Auswahl wird jedes Mal neu angehakt.
- Kein App-Store, kein Login, keine Server-Datenbank.

## Anti-Ziele

- Ein Ausschluss von Mama darf nie bei Mamas Karten durchrutschen – auch nicht in der Sammelsuche.
- Ein Design darf Lesbarkeit nicht kaputt machen (Preis und „für …“ immer klar lesbar).
- Rückgängig darf keine Geisterdaten hinterlassen (Gewichtung oder Merkliste halb zurückgedreht).

## Geänderte Grundbausteine (von Luka freigegeben, 02.11.2026: „ja du darfst die Grundbausteine ändern“)

- **7:** Gespräch statt Formular. *Ausnahme:* Das Budget wird per Regler mit Spanne abgefragt.
- **12:** Standard ist Stil C (Nachtblau/Gold). Weitere Designs sind in den Einstellungen wählbar.

## Entscheidungen im Einzelnen

### 1 · Designs (Lukas Auswahl)

Acht Designs, global für die ganze App, gewählt in den Einstellungen, gespeichert auf dem Handy.
Standard bleibt Nachtblau & Gold. Vorschauen: `.superpowers/brainstorm/2743-1793638474/content/designs*.html`.

| Name | Art | Farben (Hintergrund / Karte / Rand / Text / Akzent / Preis) |
|---|---|---|
| Nachtblau & Gold | dunkel | #11131C / #1C1F2B / #2C3040 / #EEEEEE / #E0B84C / #E0B84C |
| Waldgrün & Messing | dunkel | #0F1A14 / #18281F / #2C4335 / #EEF3EA / #C9A45C / #D8B874 |
| Bordeaux & Creme | dunkel | #1C0D11 / #2B1419 / #4A2229 / #F7ECE4 / #EFE0C8 / #EFD7B0 |
| Polarlicht | dunkel | #0A1220 / #121D30 / #24365A / #E8F1FF / #4FE0C0 / #A98BFF |
| Graphit & Lime | dunkel | #0C0C0C / #171717 / #2C2C2C / #F5F5F5 / #C8F53C / #C8F53C |
| Mint & Marine | hell | #EEF6F3 / #FFFFFF / #CFE3DC / #12263A / #14375E / #1F8A70 |
| Art déco | dunkel, besonders | #0E1A17 / #13241F / Gold #C9A45C, Text #E9DCB8; Serifenschrift, doppelter Goldrahmen, Rauten-Knöpfe, Rautenmuster im Hintergrund |
| Polaroid-Pinnwand | hell, besonders | Kork #C89A64, Karte #FDFDF8, Text #2B2118, Akzent #C0392B; Handschrift, Karte leicht schräg mit Klebestreifen, Pinnnadeln |

Die sechs „Farb“-Designs unterscheiden sich nur in Farben. Art déco und Pinnwand
haben zusätzlich eigene Schrift, Kartenform und Hintergrund. Akzentfarbe ersetzt
überall das bisherige `Look.gold`; auf Akzentflächen steht Text in einer
Kontrastfarbe (je Design festgelegt). Helle Designs schalten die Statusleiste auf dunkel.

### 2 · Sammelsuche

- Einstieg auf dem Startbildschirm: „Für mehrere suchen“ → gespeicherte Profile anhaken (mind. 2) → wischen.
- Ein gemeinsamer Stapel, gemischt (nicht zehnmal hintereinander dieselbe Person).
- Jede Karte trägt gut sichtbar „für <Name>“.
- Ausschlüsse und Budget jeder Person gelten nur für ihre Karten.
- Passt eine Karte zu mehreren, erscheint sie einmal – bei der Person, zu der sie am besten passt (höchster Score).
- Ein Ja/Nein lernt im Einzelprofil der Person mit (wie beim Einzelwischen).
- Ja → Merkliste mit dem Namen der Person.
- Auswahl wird nicht als Gruppe gespeichert.
- Wer schon etwas Gemerktes hat, bleibt normal im Stapel.
- Nur gespeicherte Profile können in die Sammelsuche (ohne Profil kein Name, keine Ausschlüsse).

### 3 · Einheitliche Bilder

Jedes Kartenbild: Seitenverhältnis 4:3, füllend zugeschnitten (scaledToFill + clipped),
gleiche Ecken. Fehlt ein Bild oder lädt es nicht: Platzhalter-Kachel in Designfarben,
gleich groß. Gilt für Wischkarte und Merkliste.

### 4 · Merkliste beim Wischen

Knopf oben rechts in der Wisch-Ansicht mit Anzahl („☰ 3“), öffnet die Merkliste als Blatt.
Beim Schließen geht das Wischen genau an der Stelle weiter.

### 5 · Preise

- Echte Produkte zeigen schon den genauen Preis – bleibt so; sicherstellen, dass nirgends „ca.“ davorsteht.
- Ideenkarten (Amazon-Suchlinks) zeigen weiter eine Spanne, weil kein konkretes Produkt dahintersteht.
- Provision gibt es auch über Suchlinks (24-h-Cookie). Genaue Amazon-Preise erst mit Produkt-API → später.

### 6 · Merkliste mit Bildern

Merklisten-Einträge zeigen das Produktbild (4:3, wie oben). Ideenkarten: Kachel in Designfarben
mit dem Suchbegriff statt Emoji. Gruppiert nach Person („für Mama“).

### 7 · Budget-Regler

- Eigene Frage im Chat, direkt nach der ersten Antwort („Für wen …?“), vor den KI-Fragen.
- Regler mit zwei Griffen (von / bis), 5–500 €, unten feinere Schritte (z. B. 5er bis 100, dann 25er).
- Knopf „Egal“ = kein Budget.
- Nach dem Bestätigen erscheint im Chat eine Nutzer-Blase „Budget: 20–50 €“ (bzw. „Budget: egal“),
  damit die KI nicht nochmal nach Geld fragt.
- Das Profil bekommt `budget_min` und `budget_max` aus dem Regler – der Regler gewinnt gegen das,
  was die KI aus dem Text liest.
- Budget-Untergrenze ist hart wie die Obergrenze (Produkte darunter werden nicht gezeigt).
  Ideenkarten: Spanne muss sich mit dem Budget überschneiden.
- Im Profil per Chat änderbar („Budget jetzt bis 100 €“) wie bisher; zusätzlich zeigt das Profil
  den Regler zum direkten Ändern. Alte Profile ohne `budget_min` funktionieren weiter (= keine Untergrenze).

### 8 · Gesehenes merken

- Gespeicherte Profile: Liste der gesehenen Karten-IDs liegt dauerhaft im Profil auf dem Handy.
  Verlassen und Wiederkommen → keine Wiederholungen.
- In „Was ich gelernt habe“: Knopf „Gesehene wieder zeigen“ leert die Liste.
- Ohne Profil: gilt, solange die Suche offen ist; versehentliches Zurück aus dem Wischen in den Chat
  und wieder hinein verliert sie nicht (Zustand hängt an der Suche, nicht an der Wisch-Ansicht).
- Gilt auch in der Sammelsuche (pro Person).

### 9 · Rückgängig

- Knopf ↶ in der Wisch-Ansicht, bis zu 10 Wischer zurück.
- Zurück kommt: die Karte (oben auf den Stapel), die Gewichtung vor dem Wischer,
  bei Ja der Merklisten-Eintrag wird entfernt, die Karte gilt wieder als ungesehen-entschieden.
- Der Verlauf gilt nur, solange die Wisch-Ansicht offen ist.

### 10 · Kleinpunkte aus v1

- M1 Doppeltipp legt Profil doppelt an → Knopf sperren.
- M2 Wisch-Ansicht wird beim Schließen eines Blatts verschluckt → Navigation reparieren.
- M3 Vom Chat kein Weg zurück ins Wischen → Knopf „Weiter wischen“, sobald es ein Profil gibt.
- M4 Chat hängt bei `fertig=false` ohne Frage → als Schlussfrage behandeln.
- M5 Kein Gesamt-Zeitlimit in `frage_json` → Obergrenze (z. B. 45 s) über alle Modelle.
- M6 Neu sortieren bei jedem Schließen von „Gelernt“ → nur, wenn sich etwas geändert hat.
- M7 Leerer Stapel: Hinweis erwähnt Budget/Ausschlüsse als mögliche Ursache.
- M9 Profiländerung während des Wischens überschreibt Gelerntes → beim Speichern zusammenführen.
- M10 `uebernimm` ignoriert geänderte Wunsch-Gewichte → übernehmen.
- M11 HTML-Reste in Beschreibungen → beim Katalogbau entfernen.

## Was dem Bauer überlassen ist

Genaue Server-Schnittstelle der Sammelsuche (eigener Endpunkt oder mehrere `/karten`-Aufrufe),
Layout der Einstellungen, Animationen, Umsetzung des Doppelreglers.
